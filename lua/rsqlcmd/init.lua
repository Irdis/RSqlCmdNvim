local M = {}

M.rsqlcmd_path = "rsqlcmd";

M.connection_strings = nil;
M.current_target = 1;
M.no_new_lines = false;

M.build = function()
    if M.rsqlcmd_exist_and_version_match() then
        return
    end
    local net_dir = M.get_net_dir()
    local has_dotnet = vim.fn.executable('dotnet') == 1

    if not has_dotnet then
        M.log('dotnet is not found. It is required to build the rsqlcmd binary. ' ..
            'Install it from https://dotnet.microsoft.com/en-us/download')
        return
    end
    M.log('Building, please wait...')
    vim.system({ 'build.bat' }, { cwd = net_dir }, function(result)
        if result.code ~= 0 then
            M.log('Failed to build dotnet binary: ' .. (result.stdout or 'unknown error'))
            return
        end
        local rsqlcmd_path = M.get_rsqlcmd_path()
        if not M.file_exists(rsqlcmd_path) then
            M.log('Unknown error, rsqlcmd binary was not found ' .. rsqlcmd_path)
            return
        end
        M.log('rsqlcmd binary built successfully!')
    end)
end

M.rsqlcmd_exist_and_version_match = function ()
    local rsqlcmd_path = M.get_rsqlcmd_path()
    if not M.file_exists(rsqlcmd_path) then
        return false
    end

    local net_dir = M.get_net_dir()

    local original_version_file = net_dir .. '/bin/version'
    if not M.file_exists(original_version_file) then
        return false
    end

    local original_version = vim.fn.readfile(original_version_file)

    local new_version_file = net_dir .. '/version'
    local new_version = vim.fn.readfile(new_version_file)

    return original_version[1] == new_version[1]
end

M.get_rsqlcmd_path = function ()
    local net_dir = M.get_net_dir()
    return net_dir .. '/bin/rsqlcmd.exe'
end

M.get_net_dir = function ()
    local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
    local net_dir = plugin_dir .. '/../net'
    return net_dir
end

M.setup = function(config)
    M.rsqlcmd_path = M.get_rsqlcmd_path()
    vim.api.nvim_create_user_command("RSqlCmd",
        M.run_cmd,
        {
            nargs = "*",
            range = true
        })
    if not config then
        return
    end
    if config.rsqlcmd_path then
        M.rsqlcmd_path = config.rsqlcmd_path
    end
    M.connection_strings = config.connection_strings
end

M.next_target = function()
    M.current_target = math.fmod(M.current_target, #M.connection_strings) + 1
    M.log("Current target: " .. M.current_target .. " " .. M.connection_strings[M.current_target])
end

M.toggle_nnl = function()
    M.no_new_lines = not M.no_new_lines
    if M.no_new_lines then
        M.log("No new lines enabled")
    else
        M.log("No new lines disabled")
    end
end

M.has_value  = function(tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

M.run_cmd = function(args)
    local lines = M.get_selection(args)
    M.run({ args = args.args, fargs = args.fargs }, lines)
end

M.get_selection = function(args)
    local start_line = args.line1
    local end_line = args.line2
    return vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
end

M.run = function(options, lines)
    local created, file_path = M.create_temp_file(lines)
    if not created then
        return
    end

    local cmd = M.build_cmd(file_path, options.args)
    M.run_in_buf(cmd, options)
end

M.create_temp_file = function(lines)
    local temp_path = vim.fn.tempname()
    local file = io.open(temp_path, "w")
    if file then
        for _, line in ipairs(lines) do
            file:write(line)
            file:write("\r\n")
        end
        file:close()
    else
        M.log("Failed to create temporary file!")
        return false, ""
    end
    return true, temp_path
end

M.run_in_buf = function(cmd, options)
    local lines = vim.fn.systemlist(cmd)

    for i, line in ipairs(lines) do
        lines[i] = string.gsub(line, "\r", "")
    end
    local buf = vim.api.nvim_create_buf(false, true)
    if M.has_value(options.fargs, "-i") then
        vim.api.nvim_buf_set_option(buf, 'filetype', 'tsql')
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    vim.api.nvim_command("split")
    vim.api.nvim_set_current_buf(buf)
end

M.build_cmd = function(file_path, args)
    local cmd = M.rsqlcmd_path
    cmd = cmd .. " -c " .. M.get_connection_string()

    if string.find(file_path, " ") then
        file_path = "\"" .. file_path .. "\"";
    end
    cmd = cmd .. " -f " .. file_path

    if M.no_new_lines then
        cmd = cmd .. " -nnl"
    end

    if args ~= "" then
        cmd = cmd .. " " .. args
    end
    return cmd
end

M.get_connection_string = function()
    return "\"" .. M.connection_strings[M.current_target] .. "\""
end

M.file_exists = function (path)
    return vim.loop.fs_stat(path) ~= nil
end

M.log = function(msg)
    print("[rsqlcmd] " .. msg)
end

return M
