vim.filetype.add({
	extension = {
		mdx = "mdx",
	},
	pattern = {
		[".*/templates/.*%.yaml"] = "helm",
		[".*/templates/.*%.yml"] = "helm",
		[".*%.tpl"] = "helm",
	},
})
