if status is-interactive
    abbr -a yz yazi
    set -gx EDITOR helix
    set -gx VISUAL helix
    abbr -a ls eza
    abbr -a cat bat

    set -g fish_key_bindings fish_vi_key_bindings

    function fish_vi_start_normal --on-event fish_prompt
        set fish_bind_mode default
    end

    # --- Top level ---
    bind -M default -m insert I 'set fish_cursor_end_mode exclusive' forward-single-char repaint-mode
    bind -M default a end-selection
    bind -M default z undo
    bind -M default Z redo
    bind -M default s delete-char
    bind -M default e edit_command_buffer
    bind -M default \ee history-pager
    bind -M default g beginning-of-line
    bind -M default ';' end-of-line
    bind -M default U beginning-of-buffer
    bind -M default D end-of-buffer
    bind -M default % beginning-of-buffer begin-selection end-of-buffer
    bind -M default -m visual x beginning-of-line begin-selection end-of-line repaint-mode
    bind -M default --erase Y
    bind -M visual Y fish_clipboard_copy
    bind -M visual -m default s kill-selection end-selection repaint-mode

    # --- w submap: word motion ---
    bind -M default w,h backward-word
    bind -M default w,H backward-bigword
    bind -M default w,l forward-word-end
    bind -M default w,L forward-bigword-end
    bind -M default w,';' forward-word-vi
    bind -M default w,':' forward-bigword-vi

    # --- H/L submap ---
    bind -M default H,space insert-line-over
    bind -M default L,space insert-line-under
    bind -M default H,f backward-jump
    bind -M default L,f forward-jump
    bind -M default H,t backward-jump-till
    bind -M default L,t forward-jump-till
    bind -M default H,b history-search-backward
    bind -M default L,b history-search-forward

    # --- C submap ---
    bind -M default C,s togglecase-char
    bind -M default C,j fish_vi_dec
    bind -M default C,k fish_vi_inc
    bind -M default C,J downcase-word
    bind -M default C,K upcase-word
    bind -M default C,c __fish_toggle_comment_commandline

    # --- p submap: paste ---
    bind -M default p,h yank
    bind -M default p,l 'set fish_cursor_end_mode exclusive' forward-char 'set fish_cursor_end_mode inclusive' yank
    bind -M default p,H fish_clipboard_paste
    bind -M default p,L 'set fish_cursor_end_mode exclusive' forward-char 'set fish_cursor_end_mode inclusive' fish_clipboard_paste
end
