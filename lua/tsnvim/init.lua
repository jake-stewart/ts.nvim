local uv = vim.loop

local function readFile(path)
    local fd = assert(uv.fs_open(path, "r", 438))
    local stat = assert(uv.fs_fstat(fd))
    local data = assert(uv.fs_read(fd, stat.size))
    assert(uv.fs_close(fd))
    return data
end

local function writeFile(path, data)
    local fd = assert(uv.fs_open(path, "w", 438))
    assert(uv.fs_write(fd, data))
    assert(uv.fs_close(fd))
end

local function fileExists(path)
    return uv.fs_stat(path)
end

local function mkdir(path)
    return uv.fs_mkdir(path, 511)
end

local function clearCmdline()
    vim.fn.feedkeys(":", "nx")
end

local function treeCheckModified(root, modifiedSince)
    local handle = assert(uv.fs_scandir(root))

    while true do
        local name, type = uv.fs_scandir_next(handle)
        if not name then
            return false
        end
        local path = root .. "/" .. name
        local stat = assert(uv.fs_stat(path))
        if stat.mtime.sec > modifiedSince
            or stat.ctime.sec > modifiedSince
        then
            return true
        end
        if type == "directory" then
            if name ~= "node_modules" then
                if treeCheckModified(path, modifiedSince) then
                    return true
                end
            end
        end
    end
end

local function ensureDirExists(path)
    if not fileExists(path) then
        assert(mkdir(path))
    end
end

local function needsRecompile(timestampPath, sourcePath)
    local success, lastModified = pcall(readFile, timestampPath)
    return not success
        or treeCheckModified(sourcePath, tonumber(lastModified))
end

local header = [[
local lua = {
    require = require,
    assert = assert,
    type = type,
    pcall = pcall,
    string = string,
    table = table,
    os = os,
    math = math,
    io = io,
}
local console = {
    __createLog = function(hl) return function(...)
        vim.api.nvim_echo({{
            table.concat(vim.tbl_map(function(e)
                return type(e) == "string" and e or vim.inspect(e)
            end, {...}), " "),
            hl
        }}, true, {})
    end end
}
console.log = console.__createLog("Normal")
console.warn = console.__createLog("WarningMsg")
console.error = console.__createLog("ErrorMsg")
]]

local function setup()
    local dataPath = vim.fn.stdpath("data") .. "/ts.nvim"
    assert(fileExists(dataPath))

    local sourcePath = vim.fn.stdpath("config") .. "/typescript"
    local cachePath = vim.fn.stdpath("state") .. "/ts.nvim"
    local modifiedTimestampPath = cachePath .. "/modified-timestamp"

    ensureDirExists(sourcePath)
    ensureDirExists(sourcePath .. "/src")
    ensureDirExists(cachePath)

    local mainTsPath = sourcePath .. "/src/main.ts"
    if not fileExists(mainTsPath) then
        uv.fs_copyfile(dataPath .. "/template/main.ts",
            mainTsPath)
    end

    local tsconfigPath = sourcePath .. "/tsconfig.json"
    if not fileExists(tsconfigPath) then
        uv.fs_copyfile(dataPath .. "/template/tsconfig.json",
            tsconfigPath)
    end

    local packageJsonPath = sourcePath .. "/package.json"
    if not fileExists(packageJsonPath) then
        uv.fs_copyfile(dataPath .. "/template/package.json",
            packageJsonPath)
    end

    if not fileExists(sourcePath .. "/node_modules") then
        if vim.fn.executable("npm") == 0 then
            vim.api.nvim_echo({
                {"[tsnvim]: npm is not installed or executable", "Error"},
            }, false, {})
            return
        end
        print("[tsnvim]: installing...");
        vim.fn.system({
            "npm",
            "--prefix",
            sourcePath,
            "install"
        })
    end

    local transpiledPath = cachePath .. "/transpiled.lua"
    local compiledPath = cachePath .. "/compiled"
    local errorMessage

    if needsRecompile(modifiedTimestampPath, sourcePath) then
        vim.cmd.messages("clear")
        clearCmdline()
        print("[tsnvim]: compiling...");
        local output = vim.fn.system({
            "npm",
            "exec",
            "--prefix",
            sourcePath,
            "--",
            "tstl",
            "--noHeader",
            "--noImplicitSelf",
            "--noImplicitGlobalVariables",
            "--luaBundle",
            transpiledPath,
            "--luaBundleEntry",
            sourcePath .. "/src/main.ts",
            "-p",
            sourcePath .. "/tsconfig.json",
        })
        if vim.v.shell_error ~= 0 then
            errorMessage = output
        else
            writeFile(transpiledPath, header .. readFile(transpiledPath))

            vim.fn.system({
                "luajit",
                "-b",
                transpiledPath,
                compiledPath,
            })

            local timestamp = vim.fn.strftime('%s')
            writeFile(modifiedTimestampPath, timestamp)
            clearCmdline()
        end
    end

    vim.cmd.luafile(compiledPath)

    if errorMessage then
        vim.defer_fn(function()
            vim.api.nvim_echo({
                {"[tsnvim]: " .. errorMessage, "Error"},
            }, false, {})
        end, 100)
    end
end

return {
    setup = setup
}
