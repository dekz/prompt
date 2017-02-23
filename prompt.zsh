# User customizable options
# PR_ARROW_CHAR="[some character]"
# RPR_SHOW_USER=(true, false) - show username in rhs prompt
# RPR_SHOW_HOST=(true, false) - show host in rhs prompt
# RPR_SHOW_GIT=(true, false) - show git status in rhs prompt

# Set custom prompt

# Allow for variable/function substitution in prompt
setopt prompt_subst

# Load color variables to make it easier to color things
autoload -U colors && colors

# The arrow symbol that is used in the prompt
PR_ARROW_CHAR="λ"
RPR_SHOW_USER=false
RPR_SHOW_HOST=false
PROMPT_MODE=0
RPR_SHOW_GIT=true # Set to false to disable git status in rhs prompt

function PR_DIR() {
    local sub=${1}
    #local _pwd="%B%c%b"
    local _pwd="%c"
    if [[ "${sub}" == "" ]]; then
      #_pwd="${${${${(@j:/:M)${(@s:/:)pwd}##.#?}:h}%/}//\%/%%}/${${pwd:t}//\%/%%}"
    fi
    echo $_pwd
}

# An exclamation point if the previous command did not complete successfully
function PR_ERROR() {
}


# The arrow in red (for root) or violet (for regular user)
function PR_ARROW() {
    echo "%B%(?:%F{green}$PR_ARROW_CHAR %f%b:%F{red}$PR_ARROW_CHAR%f%b"
}

# Set custom rhs prompt
# User in red (for root) or violet (for regular user)
function RPR_USER() {
    if [[ "${RPR_SHOW_USER}" == "true" ]]; then
        echo "%(!.%{$fg[red]%}.%{$fg[violet]%})%B%n%b%{$reset_color%}"
    fi
}

# Host in yellow
function RPR_HOST() {
    local colors
    colors=(yellow pink darkred brown neon teal)
    if [[ "${RPR_SHOW_HOST}" == "true" ]]; then
        local index=$(python -c "print(hash('$(hostname)') % ${#colors} + 1)")
        local color=$colors[index]
        echo "%{$fg[$color]%}%m%{$reset_color%}"
    fi
}

# ' at ' in orange outputted only if both user and host enabled
function RPR_AT() {
    if [[ "${RPR_SHOW_USER}" == "true" ]] && [[ "${RPR_SHOW_HOST}" == "true" ]]; then
        echo "%{$fg[blue]%} at %{$reset_color%}"
    fi
}

# Build the rhs prompt
function RPR_INFO() {
    echo "$(RPR_USER)$(RPR_AT)$(RPR_HOST)"
}

# Set RHS prompt for git repositories
DIFF_SYMBOL="*"
GIT_PROMPT_SYMBOL=""
GIT_PROMPT_PREFIX=""
GIT_PROMPT_SUFFIX=""
GIT_PROMPT_AHEAD=""
GIT_PROMPT_BEHIND=""
GIT_PROMPT_MERGING=""
GIT_PROMPT_UNTRACKED=""
GIT_PROMPT_MODIFIED="$DIFF_SYMBOL"
GIT_PROMPT_STAGED=""
GIT_PROMPT_DETACHED=""

# Show Git branch/tag, or name-rev if on detached head
function parse_git_branch() {
    (git symbolic-ref -q HEAD || git name-rev --name-only --no-undefined --always HEAD) 2> /dev/null
}

function parse_git_detached() {
    if ! git symbolic-ref HEAD >/dev/null 2>&1; then
        echo "${GIT_PROMPT_DETACHED}"
    fi
}

# Show different symbols as appropriate for various Git repository states
function parse_git_state() {
    # Compose this value via multiple conditional appends.
    local GIT_STATE=""

    local GIT_DIR="$(git rev-parse --git-dir 2> /dev/null)"
    if [ -n $GIT_DIR ] && test -r $GIT_DIR/MERGE_HEAD; then
        if [[ -n $GIT_STATE ]]; then
            GIT_STATE="$GIT_STATE "
        fi
    GIT_STATE=$GIT_STATE$GIT_PROMPT_MERGING
    fi

    if [[ -n $(git ls-files --other --exclude-standard :/ 2> /dev/null) ]]; then
    GIT_DIFF=$GIT_PROMPT_UNTRACKED
    fi

    if ! git diff --quiet 2> /dev/null; then
    GIT_DIFF=$GIT_DIFF$GIT_PROMPT_MODIFIED
    fi

#    if ! git diff --cached --quiet 2> /dev/null; then
#    GIT_DIFF=$GIT_DIFF$GIT_PROMPT_STAGED
#    fi

    if [[ -n $GIT_STATE && -n $GIT_DIFF ]]; then
        GIT_STATE="$GIT_STATE "
    fi
    GIT_STATE="$GIT_STATE$GIT_DIFF"

    if [[ -n $GIT_STATE ]]; then
    echo "$GIT_PROMPT_PREFIX$GIT_STATE$GIT_PROMPT_SUFFIX"
    fi
}

# If inside a Git repository, print its branch and state
function git_prompt_string() {
    if [[ "${RPR_SHOW_GIT}" == "true" ]]; then
        local git_where="$(parse_git_branch)"
        local git_detached="$(parse_git_detached)"
        [ -n "$git_where" ] && echo " %F{magenta}${git_where#(refs/heads/|tags/)}$git_detached$GIT_PROMPT_SUFFIX$GIT_PROMPT_SYMBOL$(parse_git_state)$GIT_PROMPT_PREFIX%f"
    fi
}

indicators=("⠂" "⠃" "⠇" "⠗" "⠷" "⠿")
function PR_JOBS {
  local _jobs=$(jobs -l | wc -l | sed -E 's/\ +$//' | sed -E 's/^\ +//')
  local indicator=${indicators[${_jobs}]}

  if [[ "$indicator" == "" ]]; then
    if [[ "${_jobs}" -gt 0 ]]; then
      # Too many jobs to display
      indicator="⠿"
    fi
  fi

  [ -n "$indicator" ] && echo "%F{magenta}$indicator%f "
}


# Function to toggle between prompt modes
function tog() {
    if [[ "${PROMPT_MODE}" == 0 ]]; then
        PROMPT_MODE=1
    elif [[ "${PROMPT_MODE}" == 1 ]]; then
        PROMPT_MODE=2
    else
        PROMPT_MODE=0
    fi
}

# Prompt
function PCMD() {
    if [[ "${PROMPT_MODE}" == 0 ]]; then
        echo "$(PR_JOBS)$(PR_DIR) $(PR_ARROW) " # space at the end
    elif [[ "${PROMPT_MODE}" == 1 ]]; then
        echo "$(PR_DIR 1) $(PR_ARROW) " # space at the end
    else
        echo "$(PR_ARROW) " # space at the end
    fi
}

PROMPT='$(PCMD)' # single quotes to prevent immediate execution
RPROMPT='' # set asynchronously and dynamically

# Right-hand prompt
function RCMD() {
    if [[ "${PROMPT_MODE}" == 0 ]]; then
        echo "$(RPR_INFO)$(git_prompt_string)"
    elif [[ "${PROMPT_MODE}" == 1 ]]; then
        echo "$(git_prompt_string)"
    else
        echo ""
    fi
}

ASYNC_PROC=0
function precmd() {
    function async() {
        # save to temp file
        printf "%s" "$(RCMD)" > "${HOME}/.zsh_tmp_prompt"

        # signal parent
        kill -s USR1 $$
    }

    # do not clear RPROMPT, let it persist

    # kill child if necessary
    if [[ "${ASYNC_PROC}" != 0 ]]; then
        kill -s HUP $ASYNC_PROC >/dev/null 2>&1 || :
    fi

    # start background computation
    async &!
    ASYNC_PROC=$!
}

function TRAPUSR1() {
    # read from temp file
    RPROMPT="$(cat ${HOME}/.zsh_tmp_prompt)"

    # reset proc number
    ASYNC_PROC=0

    # redisplay
    zle && zle reset-prompt
}

