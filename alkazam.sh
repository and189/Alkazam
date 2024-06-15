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
    # Öffne den Brave-Browser im privaten Modus mit Proxy-Einstellungen und lade eine einfache Seite
    /snap/brave/416/opt/brave.com/brave/brave-browser --incognito --proxy-server="http://$proxy_host:$proxy_port" "http://www.google.com" --enable-logging --v=1 &
    sleep 5

    # Warte auf das Proxy-Authentifizierungsfenster und fokussiere es
    xdotool search --sync --onlyvisible --class "Brave-browser" windowactivate

    # Gebe Proxy-Authentifizierungsdaten ein
    sleep 1  # kurze Pause, um sicherzustellen, dass das Fenster bereit ist
    xdotool type "$proxy_username"
    xdotool key Tab
    xdotool type "$proxy_password"
    xdotool key Return
    sleep 3
}

open_new_tab_with_url() {
    url=$1
    # Öffne eine neue Registerkarte im bestehenden Brave-Browser
    xdotool search --onlyvisible --class brave windowactivate --sync key --clearmodifiers ctrl+t
    sleep 1
    echo -n "$url" | xclip -selection clipboard
    xdotool key ctrl+l
    xdotool key ctrl+v
    xdotool key Return
    sleep 5
}

reload_tab() {
    # Lade die aktuelle Registerkarte neu
    xdotool key ctrl+r
    sleep 3
}

check_page_loaded() {
    # Überprüfe, ob die Seite geladen wurde, indem nach einem bestimmten Text gesucht wird
    xdotool key ctrl+a
    xdotool key ctrl+c
    sleep 1
    text=$(xclip -o)
    echo "Loaded text: $text"  # Debugging-Information
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
    # Überprüfe, ob der Benutzername verfügbar ist
    xdotool key ctrl+a
    xdotool key ctrl+c
    sleep 1
    text=$(xclip -o)
    echo "Username availability text: $text"  # Debugging-Information
    if [[ "$text" == *"Oops! This username is not available"* ]]; then
        return 1
    else
        return 0
    fi
}

close_tab() {
    # Schließe die aktuelle Registerkarte
    xdotool key ctrl+w
    sleep 1
}

close_browser() {
    # Schließt den Browser
    pkill brave
    sleep 5
}

restart_browser() {
    close_browser
    open_browser_with_proxy_auth
}

open_browser_with_proxy_auth

for (( i=0; i<1000; i++ )); do
    while true; do
        # Berechne den aktuellen Benutzernamen
        username="${base_username}${username_counter}"
        password="${base_password}"

        # Berechne die aktuelle E-Mail-Adresse
        email_parts=(${base_email//@/ })
        local_part=${email_parts[0]}
        domain=${email_parts[1]}

        hyphen_index=$(expr index "$local_part" "-")
        base_local=${local_part:0:$hyphen_index}
        current_number=$email_counter
        email="${base_local}${current_number}@${domain}"

        # Öffne einen neuen Tab und lade die Seite
        url="https://sso.niantic.kidswebservices.com/en/register?clientId=pokemon-go&automaticActivation=true&skipRedirect=true&hideSignIn=true&permissionsToRequest=location&dob=1452343200000"
        open_new_tab_with_url "$url"

        # Überprüfe, ob die Seite geladen wurde
        check_page_loaded
        page_status=$?
        if [ $page_status -eq 0 ]; then
            break
        elif [ $page_status -eq 2 ]; then
            # Wenn "Oops!" beim Laden der Seite gefunden wird, Browser neu starten
            restart_browser
        else
            restart_browser
        fi
    done

    while true; do
        # Fülle das Formular aus
        xdotool key Tab
        xdotool type "$username"
        xdotool key Tab
        xdotool key Tab
        xdotool type "$password"
        xdotool key Tab
        sleep 1
        xdotool key Tab
        xdotool key Tab
        xdotool key Tab

        # Überprüfe, ob der Benutzername verfügbar ist
        check_username_availability
        if [ $? -eq 0 ]; then
            break
        else
            # Benutzername nicht verfügbar, inkrementiere den Zähler und lade den Tab neu
            username_counter=$((username_counter + 1))
            reload_tab
        fi
    done

    xdotool key Return
    xdotool key Tab
    sleep 1
    xdotool type "$email"
    xdotool key Return
    sleep 5

    # Überprüfe, ob die "WOO!"-Seite geladen wurde
    check_page_loaded
    page_status=$?
    if [ $page_status -eq 3 ]; then
        # Füge den erstellten Account zur Datei hinzu
        echo "${username};${password}" >> "$accounts_file"

        # Inkrementiere die Zähler
        username_counter=$((username_counter + 1))
        created_accounts=$((created_accounts + 1))

        # Erhöhe den email_counter nur alle 50 erstellten Konten
        if [ "$created_accounts" -ge 50 ]; then
            email_counter=$((email_counter + 1))
            created_accounts=0
        fi

        # Schließe den aktuellen Tab
        close_tab
    else
        restart_browser
    fi

    # Schließe den Browser und starte ihn alle 49 Iterationen neu
    if [ $((i % 49)) -eq 0 ]; then
        restart_browser
    fi

    # Speichere die aktuellen Zählerstände in die Datei
    echo -e "$username_counter\n$email_counter\n$created_accounts" > "$counter_file"
done
