local M = {}

M.rsqlcmd_path = "rsqlcmd";

M.connection_strings = nil;
M.current_target = 1;
M.no_new_lines = false;

M.setup = function(config)
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
    M.no_new_lines = not M.no_new_lines ;
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
    print(cmd)
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

M.log = function(msg)
    print("[rsqlcmd] " .. msg)
end

return M
