#!/bin/bash

# URL to fetch job data
fetch_url="http://164.68.105.51:8787/getJob"
# Base URL to send back the result
webhook_base_url="http://164.68.105.51:8787/webhook"
job_file="/tmp/job_data.json"

# Function to open the browser and load a specific URL
open_browser() {
    echo "Attempting to open Opera browser..."
    opera --new-window --no-sandbox --enable-logging --v=1 &
    sleep 10  # Increased sleep time to allow Opera to start
    if pgrep -x "opera" > /dev/null
    then
        echo "Opera browser opened successfully."
    else
        echo "Failed to open Opera browser."
        return 1
    fi
    return 0
}

# Function to open URL in tab 2
open_url_in_tab_2() {
    local url=$1
    echo "Searching for Opera window..."
    local window_id
    window_id=$(xdotool search --onlyvisible --class "Opera" | head -n 1)
    if [ -z "$window_id" ]; then
        echo "No Opera window found"
        return 1
    fi
    echo "Found Opera window: $window_id"
    xdotool windowactivate $window_id
    sleep 1
    xdotool key ctrl+2
    sleep 1
    xdotool key ctrl+l
    sleep 1
    echo -n "$url" | xclip -selection clipboard
    xdotool key ctrl+v
    xdotool key Return
    sleep 5
    return 0
}

# Function to click in the middle of the window
click_middle_of_window() {
    local window_id=$1
    if [ -z "$window_id" ]; then
        echo "No window ID provided for middle click"
        return 1
    fi
    eval $(xdotool getwindowgeometry --shell $window_id)
    local x=$((WIDTH / 2))
    local y=$((HEIGHT / 2))
    xdotool mousemove --window $window_id $x $y click 1
    sleep 1
    return 0
}

# Function to check if the page is loaded
check_page_loaded() {
    xdotool key ctrl+a
    sleep 1
    xdotool key ctrl+c
    sleep 1
    local text
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

# Function to close the browser
close_browser() {
    pkill opera
    sleep 2
}

# Fetch job data with sudo and save to file
fetch_job_data() {
    echo "Fetching job data from $fetch_url"
    sudo curl -s "$fetch_url" -o "$job_file"
    if [ $? -ne 0 ]; then
        echo "Failed to fetch job data. Retrying..."
        sleep 5
        return 1
    fi
    return 0
}

# Function to send feedback to webhook
send_feedback() {
    local job_id=$1
    local job_result=$2
    local result_url="${webhook_base_url}?job_id=${job_id}&job_result=${job_result}"

    # Attempt to send feedback with retries
    for i in {1..3}; do
        local curl_output
        curl_output=$(sudo curl -s -w "%{http_code}" -o /dev/null "$result_url")
        if [ "$curl_output" -eq 200 ]; then
            echo "Successfully sent $job_result status for job $job_id."
            return 0
        else
            echo "Attempt $i: Failed to send $job_result status for job $job_id. HTTP status code: $curl_output"
            sleep 2
        fi
    done

    echo "Failed to send $job_result status for job $job_id after 3 attempts."
    return 1
}

# Infinite loop
while true; do
    fetch_job_data
    if [ $? -ne 0 ]; then
        continue
    fi

    job_data=$(cat "$job_file")
    echo "Job data fetched: $job_data"

    if [ -z "$job_data" ]; then
        echo "No job data received. Retrying..."
        sleep 5
        continue
    fi

    # Parse JSON data
    job_id=$(echo "$job_data" | jq -r '.job_id')
    child_username=$(echo "$job_data" | jq -r '.child_username')
    child_password=$(echo "$job_data" | jq -r '.child_password')
    parent_email=$(echo "$job_data" | jq -r '.parent_email')

    echo "Parsed job data - job_id: $job_id, child_username: $child_username, child_password: $child_password, parent_email: $parent_email"

    if [ -z "$job_id" ] || [ -z "$child_username" ] || [ -z "$child_password" ] || [ -z "$parent_email" ]; then
        echo "Incomplete job data. Retrying..."
        sleep 5
        continue
    fi

    open_browser
    if [ $? -ne 0 ]; then
        echo "Retrying to open browser..."
        continue
    fi

    attempt=0
    while [ $attempt -lt 3 ]; do
        url="https://sso.niantic.kidswebservices.com/en/register?clientId=pokemon-go&automaticActivation=true&skipRedirect=true&hideSignIn=true&permissionsToRequest=location&dob=1452343200000"
        open_url_in_tab_2 "$url"
        if [ $? -ne 0 ]; then
            continue
        fi
        check_page_loaded
        page_status=$?
        if [ $page_status -eq 0 ]; then
            break
        elif [ $page_status -eq 2 ]; then
            continue
        else
            ((attempt++))
            echo "Attempt $attempt failed. Retrying..."
            sleep 10
            continue
        fi
    done

    if [ $attempt -eq 3 ]; then
        send_feedback "$job_id" "failure"
        echo "Failed after 3 attempts. Fetching new job..."
        close_browser
        continue
    fi

    # Fill in the form and check username availability
    xdotool key Tab
    xdotool type "$child_username"
    sleep 1
    xdotool key Tab
    xdotool key Tab
    xdotool type "$child_password"
    sleep 1
    xdotool key Tab

    # Mark text and evaluate
    xclip -in -selection clipboard < /dev/null # Clear the clipboard
    window_id=$(xdotool search --onlyvisible --class "Opera" | head -n 1)
    click_middle_of_window $window_id
    xdotool key ctrl+a
    sleep 3
    xdotool key ctrl+c
    sleep 2
    text=$(xclip -o)
    echo "Username availability text: $text"
    if [[ "$text" == *"Oops! This username is not available"* ]]; then
        send_feedback "$job_id" "failure"
        close_browser
        continue  # Fetch a new job
    fi
    sleep 1
    xdotool key Tab
    sleep 1
    xdotool key Tab
    sleep 1
    xdotool key Tab
    sleep 1

    xdotool key Return
    sleep 2
    xdotool key Tab
    sleep 2
    xdotool type "$parent_email"
    xdotool key Return
    sleep 20  # Increase sleep time to ensure the page is loaded after submission

    # Check for "WOO!" text
    attempt=0
    while [ $attempt -lt 3 ]; do
        window_id=$(xdotool search --onlyvisible --class "Opera" | head -n 1)
        xdotool windowactivate $window_id
        xclip -in -selection clipboard < /dev/null # Clear the clipboard
        click_middle_of_window $window_id
        xdotool key ctrl+a
        sleep 3
        xdotool key ctrl+c
        sleep 2
        text=$(xclip -o)
        echo "Final page text: $text"
        if [[ "$text" == *"WOO!"* ]]; then
            send_feedback "$job_id" "success"
            break
        else
            ((attempt++))
            echo "Attempt $attempt failed. Retrying..."
            sleep 30
            xdotool key Tab
            xdotool key Tab
            xdotool key Tab
            xdotool key Return
            sleep 30
        fi
    done

    if [ $attempt -eq 3 ]; then
        send_feedback "$job_id" "failure"
        echo "Failed after 3 attempts to find 'WOO!'. Fetching new job..."
    fi

    close_browser
done
