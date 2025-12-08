-- Diagnostics configuration
vim.diagnostic.config({
	signs = false,
	underline = false,
	virtual_text = {
		suffix=" ",
		spacing = 2,
		prefix = "⏤",
		format = function(diagnostic)
      return diagnostic.message
    end,
	},
})
