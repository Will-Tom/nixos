# se: SESSIONS-mode actions from a shell (also works over ssh).
# Acts on the session of the shell you type it in. `se` alone shows help.
function se --description 'Persistent terminal sessions'
    ~/bin/term-sessions se $argv
end
