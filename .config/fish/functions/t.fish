function t --wraps 'eza'
	eza -lAT --group-directories-first --git --git-repos --header $argv
end