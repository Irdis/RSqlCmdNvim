# RSqlCmdNvim
A command-line tool like sqlcmd, but formats each row's columns on separate lines for improved readability.
## Installation
### lazy.nvim

``` lua
{
    "Irdis/RSqlCmdNvim",
    build = function ()
        require("rsqlcmd").build()
    end,
    config = function()
        require("rsqlcmd").setup({ 
            connection_strings = {
                "Data Source=(local);Initial Catalog=AtlasCore;Integrated Security=SSPI;TrustServerCertificate=True;Command Timeout=120",
            }
        })

        vim.keymap.set('v', '<Leader>es', ':RSqlCmd<CR>')
        vim.keymap.set('n', '<Leader>es', ':%RSqlCmd<CR>')
        vim.keymap.set('v', '<Leader>eS', ':RSqlCmd -i<CR>')
        vim.keymap.set('n', '<Leader>eS', ':%RSqlCmd -i<CR>')
    end
}
```
