#!/bin/bash

base_username="NKusernameParent"
base_password="NKuserPW"
base_email="baseemail-@domain.com" 

proxy_host="p.webshare.io"
proxy_port="80"
proxy_username="ProxyUSER"
proxy_password="ProxyPW"

counter_file="counter.txt"
accounts_file="accounts.txt"
username_counter=3
email_counter=3
created_accounts=0

if [ -f "$counter_file" ]; then
    counter_content=$(cat "$counter_file")
    IFS=$'\n' read -r -d '' -a counters <<< "$counter_content"
    username_counter=${counters[0]}
    email_counter=${counters[1]}
    created_accounts=${counters[2]}
fi

open_browser_with_proxy_auth() {
    /snap/brave/416/opt/brave.com/brave/brave-browser --incognito --proxy-server="http://$proxy_host:$proxy_port" "http://www.google.com" --enable-logging --v=1 &
    sleep 5
    xdotool search --sync --onlyvisible --class "Brave-browser" windowactivate
    sleep 2
    xdotool type "$proxy_username"
    xdotool key Tab
    xdotool type "$proxy_password"
    xdotool key Return
    sleep 3
}

open_new_tab_with_url() {
    url=$1
    xdotool search --onlyvisible --class brave windowactivate --sync key --clearmodifiers ctrl+t
    sleep 2
    echo -n "$url" | xclip -selection clipboard
    xdotool key ctrl+l
    xdotool key ctrl+v
    xdotool key Return
    sleep 5
}

reload_tab() {
    xdotool key ctrl+r
    sleep 4
}

check_page_loaded() {
    xdotool key ctrl+a
    sleep 1
    xdotool key ctrl+c
    sleep 1
    text=$(xclip -o)
    echo "Loaded text: $text"
    if [[ "$text" == *"Your username will only be used to log in."* ]]; then
        return 0
    elif [[ "$text" == *"Oops! This username is not available"* ]]; then
        return 2
    elif [[ "$text" == *"WOO!"* ]]; then
        return 3
    else
        return 1
    fi
}

check_username_availability() {
    xdotool key ctrl+a
    sleep 2
    xdotool key ctrl+c
    sleep 2
    text=$(xclip -o)
    echo "Username availability text: $text"
    if [[ "$text" == *"Oops! This username is not available"* ]]; then
        return 1
    else
        return 0
    fi
}

focus_back_to_username_field() {
    # Beispielkoordinaten, die auf das Benutzernamenfeld zeigen - diese müssen möglicherweise angepasst werden
    xdotool mousemove 300 300 click 1
    sleep 1
}

close_tab() {
    xdotool key ctrl+w
    sleep 2
}

close_browser() {
    pkill brave
    sleep 2
}

restart_browser() {
    close_browser
    open_browser_with_proxy_auth
}

open_browser_with_proxy_auth

for (( i=0; i<1000; i++ )); do
    while true; do
        username="${base_username}${username_counter}"
        password="${base_password}"
        email_parts=(${base_email//@/ })
        local_part=${email_parts[0]}
        domain=${email_parts[1]}
        hyphen_index=$(expr index "$local_part" "-")
        base_local=${local_part:0:$hyphen_index}
        current_number=$email_counter
        email="${base_local}${current_number}@${domain}"
        url="https://sso.niantic.kidswebservices.com/en/register?clientId=pokemon-go&automaticActivation=true&skipRedirect=true&hideSignIn=true&permissionsToRequest=location&dob=1452343200000"
        open_new_tab_with_url "$url"
        check_page_loaded
        page_status=$?
        if [ $page_status -eq 0 ]; then
            break
        elif [ $page_status -eq 2 ]; then
            restart_browser
        else
            restart_browser
        fi
    done

    # Fülle das Formular aus und überprüfe die Verfügbarkeit des Benutzernamens
    xdotool key Tab
    xdotool type "$username"
    sleep 2
    xdotool key Tab
    xdotool key Tab
    xdotool type "$password"
    xdotool key ctrl+c
    xdotool key ctrl+a
    xdotool mousemove 960 100 click 1

    # Text markieren und auswerten
    xdotool key ctrl+a
    sleep 3
    xdotool key ctrl+c
    sleep 2
    echo "Username availability text: $text"
    if [[ "$text" == *"Oops! This username is not available"* ]]; then
        username_counter=$((username_counter + 1))
        echo -e "$username_counter\n$email_counter\n$created_accounts" > "$counter_file"
        continue  # Zum nächsten Benutzernamen wechseln
    fi
    xdotool key Tab
    xdotool key Tab
    xdotool key Tab
    xdotool key Tab
    xdotool key Tab
    xdotool key Tab
    xdotool key Tab

    xdotool key Return
    sleep 2
    xdotool key Tab
    sleep 2
    xdotool type "$email"
    xdotool key Return
    sleep 3
    check_page_loaded
    page_status=$?
    if [ $page_status -eq 3 ]; then
        echo "${username};${password};${email}" >> "$accounts_file"
        created_accounts=$((created_accounts + 1))
        if [ "$created_accounts" -ge 50 ]; then
            email_counter=$((email_counter + 1))
            created_accounts=0
        fi
        echo -e "$username_counter\n$email_counter\n$created_accounts" > "$counter_file"
        username_counter=$((username_counter + 1))
        close_tab
    else
        username_counter=$((username_counter + 1))
        restart_browser
    fi

    if [ $((i % 49)) -eq 0 ]; then
        restart_browser
    fi
done

done

