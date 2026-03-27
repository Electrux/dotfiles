if status is-interactive
	# Commands to run in interactive sessions can go here

	if not test -f $__fish_config_dir/.first-run
		curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
		fisher install jorgebucaran/fisher && fisher install jorgebucaran/spark.fish decors/fish-colored-man IlanCosman/tide@v6 rose-pine/fish
		tide configure --auto --style=Rainbow --prompt_colors='16 colors' --show_time='24-hour format' --rainbow_prompt_separators=Slanted --powerline_prompt_heads=Slanted --powerline_prompt_tails=Slanted --powerline_prompt_style='Two lines, character and frame' --prompt_connection=Dotted --powerline_right_prompt_frame=Yes --prompt_spacing=Sparse --icons='Many icons' --transient=No
		fish_config theme choose "Rosé Pine Auto"
		set --universal tide_pwd_color_anchors black
		set --universal tide_pwd_color_dirs black
		set --universal tide_pwd_color_truncated_dirs black
		touch $__fish_config_dir/.first-run
	end

	# Setup fzf
	fzf --fish | source

	# Git commands
	abbr --add ga 'git add'
	abbr --add gb 'git branch'
	abbr --add gc 'git commit'
	abbr --add gd 'git diff'
	abbr --add gp 'git push'
	abbr --add gs 'git status'

	# Neovim
	abbr --add v 'nvim'
	abbr --add vim 'nvim'

	# Feral programs
	abbr --add n 'feral todo'
	abbr --add c 'feral build-project'

	# Stuff to run
	fastfetch
	if type -q feral
		feral todo l
		echo
	end
end