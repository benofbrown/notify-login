#   notify-login.sh - send an email when someone logs in
#
#   Copyright 2016 Ben Brown
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#



notify_login() {
  #### Configuration ####

  # Email address notifications are to be sent to
  local MAILTO=root

  # Use the full hostname in the email subject line.
  # Valid values are 'yes' or 'no'
  local USE_FULL_HOSTNAME=yes


  #### End Configuration ####

  # PATHS. Shouldn't need to change these.
  local CMD_MAILX=/usr/bin/mailx
  local CMD_PS=/bin/ps
  local CMD_CAT=/bin/cat
  local CMD_TTY=/usr/bin/tty
  local CMD_TR=/usr/bin/tr
  local CMD_HOSTNAME=/bin/hostname

  local SUBJECT_HOST
  local FQDN=$($CMD_HOSTNAME -f)
  if [ "$USE_FULL_HOSTNAME" == yes ]; then
    SUBJECT_HOST="$FQDN"
  else
    SUBJECT_HOST=$($CMD_HOSTNAME -s)
  fi

  local SUBJECT="Login notification from $SUBJECT_HOST"

  if [ -z "$USER" ]; then
    USER=$($CMD_PS -o user= $$)
  fi

  if [ "$USER" != "root" ]; then
    if $CMD_TTY -s; then
      local USERTTY=" on $($CMD_TTY)"
    fi
    if [ -n "$SSH_CONNECTION" ]; then
      local REMOTEIP="from ${SSH_CONNECTION%% *}"
    fi

    $CMD_CAT <<EOF | $CMD_MAILX -s "$SUBJECT" "$MAILTO"
To: <$MAILTO>
From: <root@$FQDN>

User $USER logged in ${REMOTEIP}$CMD_TTY
EOF
    return
  fi

  local ppid=$$
  local puser
  local pdata

  while [ $ppid -ne 1 ]; do
    pdata=$($CMD_PS -o ppid= -o user= $ppid)
    puser=${pdata##* }
    [ "$puser" != "root" ] && break
    ppid=${pdata% *}
  done

  local REMOTEIP="from $(
    $CMD_TR '\000' '\n' < /proc/$ppid/environ \
    | while IFS='=' read -r k v; do
      if [ "$k" = "SSH_CONNECTION" ]; then
        echo "${v%% *}"
        break
      fi
    done
  )"


  if [ $ppid -eq 1 ]; then
    local USERTTY=$($CMD_TTY 2>&1)
    $CMD_CAT <<EOF | $CMD_MAILX -s "$SUBJECT" "$MAILTO"
To: <$MAILTO>
From: <root@$FQDN>

User root logged in on $USERTTY
EOF
  else
    local USERTTY=$($CMD_PS -o tty= $ppid)
    $CMD_CAT <<EOF | $CMD_MAILX -s "$SUBJECT" "$MAILTO"
To: <$MAILTO>
From: <root@$FQDN>

User $puser escalated to root in on $TTY
EOF
  fi
}

notify_login
unset -f notify_login
