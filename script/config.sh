#!/bin/bash
# --------------------------------------------
# Configure some terminal settings.
#
# Author : Keegan Mullaney
# Website: keegoid.com
# Email  : keegan@kmauthorized.com
# License: keegoid.mit-license.org
# --------------------------------------------

{ # this ensures the entire script is downloaded #

# --------------------------  SETUP PARAMETERS

[ -z "$QC_CONFIG" ] && QC_CONFIG="$HOME/.qc"
[ -z "$QC_BACKUP" ] && QC_BACKUP="$QC_CONFIG/backup"
[ -z "$QC_SYNCED" ] && QC_SYNCED="$QC_CONFIG/config"

# system and program config files
CONF1="$HOME/.bashrc"
CONF2="$HOME/.inputrc"
CONF4="$HOME/.muttrc"
CONF5="$HOME/.vimrc"
CONF6="$HOME/.gitignore_global"
#CONF7="$HOME/.byobu"
CONF8="$HOME/.bash_aliases"

# config files copied from repositories
#REPO1="$QC_CONFIG/aliases/bash_aliases.conf"
REPO2="$QC_CONFIG/zlua/zlua.conf"
REPO4="$QC_CONFIG/mutt/colors/mutt-colors-solarized-dark-16.muttrc"
REPO5="$QC_CONFIG/vim/vim.conf"
REPO6="$QC_CONFIG/git/gitignore_global"
REPO7="$QC_CONFIG/bashrc/ps1.conf"

# --------------------------  BACKUPS

# backup config files
qc_do_backup() {
  local name
  local today

  lkm_confirm "Backup config files before making changes?" true
  RET="$?"
  [ $RET -gt 0 ] && return 1

  today=$(date +%Y%m%d_%s)
  mkdir -pv "$QC_BACKUP-$today"

  for i in $1
  do
    if [ -e "$i" ] && [ ! -L "$i" ]; then
      name=$(lkm_trim_longest_left_pattern "$i" "/")
      cp "$i" "$QC_BACKUP-$today/$name" && lkm_success "made backup: $QC_BACKUP-$today/$name"
    fi
  done

  RET="$?"
  lkm_debug

  return 0
}

# --------------------------  MORE SECURE LOGIN SCREEN

# sudo mkdir -p /etc/lightdm/lightdm.conf.d
# cat '[SeatDefaults] \
# user-session=ubuntu \
# greeter-show-manual-login=true \
# greeter-hide-users=true \
# allow-guest=false'

# --------------------------  INOTIFY FIX

# fix error when too many files in a directory
qc_set_inotify_max() {
  local conf_file="$1"

  if grep -q "max_user_watches=524288" "$conf_file" >/dev/null 2>&1; then
    echo "already set fs.inotify.max_user_watches"
  else
    echo fs.inotify.max_user_watches=524288 | sudo tee -a "$conf_file" && sudo sysctl -p
  fi

  RET="$?"
  lkm_debug
}

# --------------------------  TILIX FIX

# fix Tilix in Ubuntu
qc_set_tilix() {
  local conf_file="$1"

  if grep -q "TILIX_ID" "$conf_file" >/dev/null 2>&1; then
    echo "already added Tilix fix"
  else
    lkm_pause "Press [Enter] to configure Tilix in $conf_file" true
cat << 'EOF' >> "$conf_file"
if [ $TILIX_ID ] || [ $VTE_VERSION ]; then
        source /etc/profile.d/vte.sh
fi
EOF
    lkm_success "configured: $conf_file (Tilix)"
    sudo ln -s /etc/profile.d/vte-2.91.sh /etc/profile.d/vte.sh
    lkm_success "configured: symlink to vte-2.91.sh"
    sudo update-alternatives --config x-terminal-emulator
    lkm_success "configured: system default terminal emulator"
  fi

  RET="$?"
  lkm_debug
}

# --------------------------  BYOBU PROMPT

# check if byobu is installed and set prompt
qc_set_byobu_prompt() {
  local conf_file="$1"

  if lkm_not_installed "byobu"; then
    echo -e " ${YELLOW_BLACK} * byobu [not installed] ${NONE_WHITE}, skipping..."
  else
    pkg_version=$(dpkg -s "byobu" 2>&1 | grep 'Version:' | cut -d " " -f 2)
    lkm_print_pkg_info "byobu" "$pkg_version"
    if grep -q ".byobu/prompt" "$conf_file" >/dev/null 2>&1; then
      echo "already configured byobu-prompt"
    else
      lkm_pause "Press [Enter] to configure byobu-prompt" true
      byobu-prompt
      lkm_success "configured: $conf_file"
    fi
  fi

  RET="$?"
  lkm_debug
}

# --------------------------  GIT CONFIG

# clone or pull git repo and copy repo file onto conf file
qc_set_git_config() {
  local repo_url="$1"
  local conf_file="$CONF6"
  local repo_file="$REPO6"
  local repo_dir
  local repo_name
  local cloned=1

  repo_dir=$(lkm_trim_shortest_right_pattern "$REPO6" "/")
  repo_name=$(lkm_trim_longest_left_pattern "$repo_dir" "/")

  # update or clone repository
  if [ -d "$repo_dir" ]; then
    (
      cd "$repo_dir" || exit
      echo "checking for updates: $repo_name"
      git pull
    )
  else
    git clone "$repo_url" "$repo_dir" && cloned=0
  fi

  # copy config file to proper location
  cp "$repo_file" "$conf_file"
  RET="$?"
  if [ $RET -eq 0 ] && [ "$cloned" -eq 0 ]; then
    lkm_success "configured: $conf_file"
  fi

  # check if git is already configured
  if ! git config --list | grep -q "user.name"; then
    read -rep "your name for git commit logs: " -i 'Keegan Mullaney' real_name
    read -rep "your email for git commit logs: " -i 'keegan@kmauthorized.com' email_address
    read -rep "your preferred text editor for git commits: " -i 'vi' git_editor
    read -rep "your GPG signing key to sign git commits: " -i '0D8F7627F4E5B8C0' gpg_key
    lkm_configure_git "$real_name" "$email_address" "$git_editor" "$gpg_key" && lkm_success "configured: $CONF6"
  fi

# todo:
# [diff]
#     tool = default-difftool
# [difftool "default-difftool"]
#     cmd = code --wait --diff $LOCAL $REMOTE

  RET="$?"
  lkm_debug
}

# --------------------------  TERMINAL HISTORY LOOKUP (also awesome)

qc_set_terminal_history() {
  local conf_file="$1"

  [ -f "$conf_file" ] || touch "$conf_file"
  if grep -q "backward-char" "$conf_file" >/dev/null 2>&1; then
    echo "already added terminal history lookup (usage: start of command + up arrow)"
  else
    lkm_pause "Press [Enter] to configure .inputrc" true
cat << 'EOF' >> "$conf_file"
"\e[A": history-search-backward
"\e[B": history-search-forward
"\e[C": forward-char
"\e[D": backward-char
EOF
    lkm_success "configured: $conf_file (usage: start of command + up arrow)"
  fi

  RET="$?"
  lkm_debug
}

# --------------------------  Z.LUA (so awesome)

qc_set_zlua_config() {
  local src_repo_url="$1"
  local conf_repo_url="$2"
  local conf_repo_dir
  local conf_repo_name

  conf_repo_dir=$(lkm_trim_shortest_right_pattern "$REPO2" "/")
  conf_repo_name=$(lkm_trim_longest_left_pattern "$conf_repo_dir" "/")

  # update or clone repository for conf file
  if [ -d "$conf_repo_dir" ]; then
    (
      cd "$conf_repo_dir" || exit
      echo "checking for updates: $conf_repo_name"
      git pull
    )
  else
    git clone "$conf_repo_url" "$conf_repo_dir"
  fi

  # remove temp directory if it exists
  rm -rf /tmp/zlua

  # clone source repository and copy src file to src_dir
  mkdir -p /tmp/zlua
  git clone "$src_repo_url" /tmp/zlua

  # update or clone repository for conf file
  mkdir -p "$HOME/bin"
  cp -f /tmp/zlua/z.lua "$HOME/bin/"

  if grep -q "z.lua enhanced matching" "$CONF1" >/dev/null 2>&1; then
    echo "already added z.lua config to $CONF1"
  else
    lkm_pause "Press [Enter] to configure z.lua for bash" true
    # shellcheck disable=SC1090
    cat "$REPO2" >> "$CONF1" && lkm_success "configured: $CONF1 with z.lua (usage: z foo)" \
    && lkm_success "Close and reopen the terminal to start using z"
  fi

  # shellcheck disable=SC2034
  RET="$?"
  lkm_debug
}

# --------------------------  SET PS1

qc_set_ps1() {
  local repo_url="$1"
  local src_cmd="$2"
  local conf_file="$CONF1"
  local repo_file="$REPO7"
  local repo_dir
  local repo_name
  local configured=1

  repo_dir=$(lkm_trim_shortest_right_pattern "$REPO7" "/")
  repo_name=$(lkm_trim_longest_left_pattern "$repo_dir" "/")

  # update or clone repository
  if [ -d "$repo_dir" ]; then
    (
      cd "$repo_dir" || exit
      echo "checking for updates: $repo_name"
      git pull
    )
  else
    git clone "$repo_url" "$repo_dir"
  fi

  # check if already added, else set source command in conf_file
  if grep -q "bashrc/ps1.conf" "$conf_file" >/dev/null 2>&1; then
    echo "already added custom PS1 file"
  # else
    # lkm_pause "Press [Enter] to configure PS1 variable for gnome-terminal" true
    # shellcheck disable=SC1090
    #FIXME: use EOF to insert block of text where needed
    # sed -i.bak -e '0,/PS1=/s//#PS1=/' -e "/\"\$color_prompt\" = yes/ a $src_cmd" "$conf_file" && configured=0
  fi

  RET="$?"

  # success message
  if [ $RET -eq 0 ] && [ "$configured" -eq 0 ]; then
    lkm_success "configured: $conf_file with custom PS1 variable"
    echo "Close and reopen the terminal to see the new prompt string."
  fi

  RET="$?"
  lkm_debug
}

# --------------------------  UNSET FUNCTIONS

# unset the various functions defined during execution of the script
qc_reset() {
  unset -f qc_do_backup qc_set_inotify_max qc_set_tilix qc_set_byobu_prompt qc_set_git_config qc_set_terminal_history qc_set_zlua_config qc_set_ps1
}

# --------------------------  MAIN

lkm_pause "" true

qc_do_backup            "$CONF1 $CONF2 $CONF4 $CONF5 $CONF6 $CONF8"

# bash aliases
lkm_set_sourced_config  "https://gist.github.com/9d74e08779c1db6cb7b7.git" \
                        "$CONF1" \
                        "$REPO1" \
                        "\n# source alias file\nif [ -f $REPO1 ]; then\n   . $REPO1\nfi"

# mutt config
lkm_set_sourced_config  "https://github.com/altercation/mutt-colors-solarized.git" \
                        "$CONF4" \
                        "$REPO4" \
                        "# source colorscheme file\nsource $REPO4\n\n# signature and alias files\nset signature=$QC_SYNCED/mutt/sig\nset alias_file=$QC_SYNCED/mutt/aliases\n\n# aliases are stored in their own file\nsource \"\$alias_file\""

# vim config
lkm_set_sourced_config  "https://gist.github.com/00a60c7355c27c692262.git" \
                        "$CONF5" \
                        "$REPO5" \
                        "\" source config file\n:so $REPO5\n\nset spellfile=$QC_SYNCED/vim/vim.utf-8.add\t\" spell check file to sync with other computers"

[ -d "$QC_SYNCED/vim" ] || { mkdir -pv "$QC_SYNCED/vim"; lkm_notify3 "note: vim spellfile will be located in $QC_SYNCED/vim, you can change this in $CONF5"; }

qc_set_inotify_max      "/etc/sysctl.conf"

qc_set_tilix            "$CONF1"

qc_set_byobu_prompt     "$CONF1"

qc_set_git_config       "https://gist.github.com/efa547b362910ac7077c.git"

qc_set_terminal_history "$CONF2"

qc_set_zlua_config      "https://github.com/skywind3000/z.lua.git" \
                        "https://gist.github.com/cbd2ac6f2be16266aba0e1554a93f759.git"

qc_set_ps1              "https://gist.github.com/keegoid-nr/3648cd615741224a253349ac517c4703" \
                        "# source PS1 file\n  if [ -f $REPO7 ]; then\n    . $REPO7\n  fi"

qc_reset

} # this ensures the entire script is downloaded #
