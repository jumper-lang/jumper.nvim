-- jumper.nvim: the Jumper language in Neovim - .jmp scripts, .jmc configs, .jma access policies - with its
-- language server `jmp --lsp` (Java 21+). With lazy.nvim / LazyVim, one spec:
--
--   { "jumper-lang/jumper.nvim", lazy = false, opts = {} }
--
-- The server is a release of the language (https://github.com/jumper-lang/jumper): the version pinned below,
-- checked against its SHA-256 and kept in stdpath("data")/jumper/. The first Jumper file you open downloads it
-- (curl; Windows 10+, macOS and Linux have it); :JumperInstall downloads it again.
--
-- Options, all optional:
--   java     = nil   a `java` 21+; default: $JAVA_HOME/bin/java, then `java` on the PATH
--   jar      = nil   a jmp.jar to run instead of the released one (e.g. lang/build/libs/jmp.jar of a build)
--   jvm_args = {}    extra JVM arguments: { "-Xmx512m" }, { "-Djmp.cfr=off" }
--
-- The filetype, the syntax (syntax/jumper.vim) and the filetype plugin are this plugin's; the server adds semantic
-- tokens, diagnostics, hover, completion, go-to-definition (into Java too), references, rename, outline, code
-- actions, formatting, folding and inlay hints. Do not register the Java tree-sitter parser for `jumper`: it does
-- not know `dyn` and table literals.
local M = {}

--- The language server this version of the plugin runs: a release of jumper-lang/jumper. `sha256` is the content
--- of that release's jmp.jar.sha256; nil (a version not pinned yet) - the release's own jmp.jar.sha256 is trusted.
M.server = {
  version = "0.11.0",
  sha256 = "fec89991055699f69c39112e4024e7f088dd023c8f8b8560511090b1d9a31c4d",
}

local RELEASES = "https://github.com/jumper-lang/jumper/releases/download/"

M.opts = { java = nil, jar = nil, jvm_args = {} }

local function data_dir()
  return vim.fn.stdpath("data") .. "/jumper"
end

--- Where the released server is kept: one jar per version.
function M.jar_path()
  return data_dir() .. "/jmp-" .. M.server.version .. ".jar"
end

local function java()
  if M.opts.java then return M.opts.java end
  local home = vim.env.JAVA_HOME
  if home and home ~= "" then
    local exe = home .. "/bin/java" .. (vim.fn.has("win32") == 1 and ".exe" or "")
    if vim.fn.executable(exe) == 1 then return exe end
  end
  return "java"
end

local function notify(msg, level)
  vim.schedule(function() vim.notify("Jumper: " .. msg, level or vim.log.levels.INFO) end)
end

--- Run a command, then `done(code, stdout)` on the main loop.
local function run(cmd, done)
  if vim.system then
    vim.system(cmd, { text = true }, function(r) vim.schedule(function() done(r.code, r.stdout or "") end) end)
  else
    local out = {}
    vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      on_stdout = function(_, data) out = data or {} end,
      on_exit = function(_, code) vim.schedule(function() done(code, table.concat(out, "\n")) end) end,
    })
  end
end

--- The SHA-256 of a file with what the system has: certutil (Windows), sha256sum (Linux), shasum (macOS).
local function file_sha256(path, done)
  local cmd
  if vim.fn.has("win32") == 1 then
    cmd = { "certutil", "-hashfile", path, "SHA256" }
  elseif vim.fn.executable("sha256sum") == 1 then
    cmd = { "sha256sum", path }
  elseif vim.fn.executable("shasum") == 1 then
    cmd = { "shasum", "-a", "256", path }
  else
    return done(nil)
  end
  run(cmd, function(code, out)
    if code ~= 0 then return done(nil) end
    -- the first 64 hex digits (certutil of old Windows puts spaces between the bytes)
    for line in out:gmatch("[^\r\n]+") do
      local hex = line:gsub("%s", ""):lower():match("^(%x+)")
      if hex and #hex >= 64 then return done(hex:sub(1, 64)) end
    end
    done(nil)
  end)
end

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local installing, waiting = false, {}

--- Download the pinned server into stdpath("data")/jumper and check it, then `done(path)` (`done(nil)` if that failed).
function M.install(done)
  table.insert(waiting, done or function() end)
  if installing then return end
  installing = true
  vim.fn.mkdir(data_dir(), "p")
  local v = M.server.version
  local url = RELEASES .. "v" .. v .. "/jmp.jar"
  local target, part, sumfile = M.jar_path(), M.jar_path() .. ".part", M.jar_path() .. ".sha256"
  local function finish(path, err)
    os.remove(part)
    os.remove(sumfile)
    if err then notify(err .. "; set `jar` in the options to a jmp.jar", vim.log.levels.ERROR) end
    installing = false
    local cbs = waiting
    waiting = {}
    for _, cb in ipairs(cbs) do cb(path) end
  end
  local function check(expected)
    file_sha256(part, function(got)
      if not got then return finish(nil, "no sha256sum/shasum/certutil to check the language server with") end
      if got ~= expected then
        return finish(nil, "jmp.jar " .. v .. " from " .. url .. " has SHA-256 " .. got .. ", expected " .. expected)
      end
      os.remove(target)
      os.rename(part, target)
      notify("language server " .. v .. " installed: " .. target)
      finish(target)
    end)
  end
  notify("downloading the language server " .. v .. "...")
  run({ "curl", "-fsSL", "--retry", "2", "-o", part, url }, function(code)
    if code ~= 0 then return finish(nil, "could not download " .. url) end
    if M.server.sha256 then return check(M.server.sha256) end
    run({ "curl", "-fsSL", "--retry", "2", "-o", sumfile, url .. ".sha256" }, function(c2)
      local expected = c2 == 0 and (read(sumfile) or ""):match("^%s*(%x+)") or nil
      if not expected or #expected ~= 64 then return finish(nil, "could not download " .. url .. ".sha256") end
      check(expected:lower())
    end)
  end)
end

local function start(buf, jar)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local cmd = { java(), "-Xss16m" }
  vim.list_extend(cmd, M.opts.jvm_args or {})
  vim.list_extend(cmd, { "-cp", jar, "me.padej.jumper.Main", "--lsp" })
  local name = vim.api.nvim_buf_get_name(buf)
  vim.lsp.start({
    name = "jumper",
    cmd = cmd,
    -- the server finds each file's context itself (its host, policy and classes): no project root is needed,
    -- one process serves every file
    root_dir = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd(),
  }, {
    bufnr = buf,
    reuse_client = function(client, config) return client.name == config.name end,
  })
end

--- Start (or attach to) the language server for a Jumper buffer, installing the server first if needed.
function M.attach(buf)
  local jar = M.opts.jar
  if jar then
    if vim.fn.filereadable(jar) == 1 then
      start(buf, jar)
    else
      notify("no jmp.jar at " .. jar, vim.log.levels.ERROR)
    end
    return
  end
  jar = M.jar_path()
  if vim.fn.filereadable(jar) == 1 then return start(buf, jar) end
  M.install(function(path) if path then start(buf, path) end end)
end

local function attach_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "jumper" then M.attach(buf) end
  end
end

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
  vim.filetype.add({ extension = { jmp = "jumper", jmc = "jumper", jma = "jumper" } })

  local group = vim.api.nvim_create_augroup("jumper", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "jumper",
    callback = function(ev) M.attach(ev.buf) end,
  })
  -- the Java sources and outlines that go-to-definition opens are for reading
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    pattern = "*/jumper/sources/*",
    callback = function(ev)
      vim.bo[ev.buf].modifiable = false
      vim.bo[ev.buf].readonly = true
    end,
  })
  vim.api.nvim_create_user_command("JumperInstall", function()
    os.remove(M.jar_path())
    M.install(function(path)
      if not path then return end
      local get = vim.lsp.get_clients or vim.lsp.get_active_clients
      for _, c in ipairs(get({ name = "jumper" })) do vim.lsp.stop_client(c.id) end
      vim.defer_fn(attach_all, 500)
    end)
  end, { desc = "Download the Jumper language server again" })

  -- buffers opened before the plugin loaded
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf):match("%.jm[pca]$") then
      if vim.bo[buf].filetype ~= "jumper" then
        vim.bo[buf].filetype = "jumper"   -- fires FileType, which attaches
      else
        M.attach(buf)
      end
    end
  end
end

return M
