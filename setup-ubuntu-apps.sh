#!/usr/bin/env bash

# Function to log and handle errors
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# Update the system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y || handle_error "Failed to update package lists."

# Ensure wget and curl are installed
if ! command -v wget &> /dev/null || ! command -v curl &> /dev/null; then
    echo "Installing wget and curl..."
    sudo apt install -y wget curl || handle_error "Failed to install wget or curl."
fi

# Software options
declare -A software=(
    [jetbrains-toolbox]="JetBrains Toolbox"
    [github-desktop]="GitHub Desktop"
    [discord]="Discord"
    [google-chrome]="Google Chrome"
    [1password]="1Password"
)

# Functions to install each application
install_jetbrains_toolbox() {
    echo "Installing JetBrains Toolbox..."

    # Ensure dependencies are installed
    for cmd in curl jq tar; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "$cmd is not installed. Installing $cmd..."
            sudo apt update -y || handle_error "Failed to apt update."
            sudo apt install -y "$cmd" || handle_error "Failed to install $cmd."
        fi
    done

    # Fetch the JSON data
    json_data="$(curl -fsSL 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release')" \
        || handle_error "Failed to fetch JSON data from JetBrains API."

    # Parse the JSON to get the latest Linux download link
    latest_url="$(echo "$json_data" | jq -r '.TBA[0].downloads.linux.link // empty')"

    # Validate the URL
    if [[ -z "$latest_url" || ! "$latest_url" =~ ^https:// ]]; then
        echo "Debug: JSON data received: $json_data" >&2
        handle_error "Failed to fetch a valid JetBrains Toolbox URL."
    fi

    echo "Latest JetBrains Toolbox URL: $latest_url"

    # Work in a temp directory
    tmpdir="$(mktemp -d)" || handle_error "Failed to create temp directory."
    trap 'rm -rf "$tmpdir"' RETURN

    # Download & extract
    archive="$tmpdir/jetbrains-toolbox.tar.gz"
    curl -fL "$latest_url" -o "$archive" || handle_error "Failed to download JetBrains Toolbox."

    tar -xzf "$archive" -C "$tmpdir" || handle_error "Failed to extract JetBrains Toolbox."

    # Find extracted directory
    extracted_dir="$(find "$tmpdir" -maxdepth 1 -type d -name 'jetbrains-toolbox-*' | head -n 1)"
    [[ -n "$extracted_dir" ]] || handle_error "Could not find extracted jetbrains-toolbox directory."

    # Install location: keep the full directory
    install_root="$HOME/.local/share/JetBrains"
    install_dir="$install_root/Toolbox"
    mkdir -p "$install_root" || handle_error "Failed to create $install_root."

    # Replace any existing install
    rm -rf "$install_dir" || handle_error "Failed to remove existing Toolbox install."
    mv "$extracted_dir" "$install_dir" || handle_error "Failed to move Toolbox into $install_dir."

    # Ensure local bin exists
    mkdir -p "$HOME/.local/bin" || handle_error "Failed to create ~/.local/bin."

    # Symlink the launcher into ~/.local/bin
    launcher="$install_dir/bin/jetbrains-toolbox"
    [[ -x "$launcher" ]] || handle_error "Toolbox launcher not found or not executable at: $launcher"

    ln -sf "$launcher" "$HOME/.local/bin/jetbrains-toolbox" \
        || handle_error "Failed to create symlink in ~/.local/bin."

    echo "JetBrains Toolbox installed."
    echo "Run it with: ~/.local/bin/jetbrains-toolbox"
    echo "If that command is not found, ensure ~/.local/bin is in your PATH."
}


install_discord() {
    echo "Installing Discord..."

    # Define the Discord download URL
    discord_url="https://discord.com/api/download?platform=linux&format=deb"

    # Download the Discord .deb package
    wget -O discord.deb "$discord_url" || handle_error "Failed to download Discord."

    # Verify the downloaded file exists and is valid
    if [ ! -f discord.deb ]; then
        handle_error "Discord .deb package not found after download."
    fi

    # Attempt to install the package
    sudo dpkg -i discord.deb || {
        echo "Resolving dependencies and retrying installation..."
        sudo apt-get install -f -y || handle_error "Failed to resolve dependencies for Discord."
        sudo dpkg -i discord.deb || handle_error "Failed to install Discord after resolving dependencies."
    }

    rm -f discord.deb || handle_error "Failed to clean up Discord temporary files."

    echo "Discord installed successfully."
}

install_google_chrome() {
    echo "Installing Google Chrome..."
    wget -O google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb || handle_error "Failed to download Google Chrome."
    sudo apt install -y ./google-chrome.deb || handle_error "Failed to install Google Chrome."
    rm -f google-chrome.deb || handle_error "Failed to clean up Google Chrome temporary files."
}

install_github_desktop() {
    echo "Installing GitHub Desktop..."
    
    # Add the repository key and source
    curl -fsSL https://packagecloud.io/shiftkey/desktop/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/github-desktop-keyring.gpg || handle_error "Failed to add GitHub Desktop GPG key."
    echo "deb [signed-by=/usr/share/keyrings/github-desktop-keyring.gpg] https://packagecloud.io/shiftkey/desktop/any/ any main" | sudo tee /etc/apt/sources.list.d/github-desktop.list || handle_error "Failed to add GitHub Desktop repository."
    
    # Update the package list and install GitHub Desktop
    sudo apt update && sudo apt install -y github-desktop || handle_error "Failed to install GitHub Desktop."
}

install_1password() {
    echo "Installing 1Password..."

    # Define the temporary download location
    tmp_deb="/tmp/1password-latest.deb"

    # Download the latest 1Password .deb package
    wget -O "$tmp_deb" https://downloads.1password.com/linux/debian/amd64/stable/1password-latest.deb || handle_error "Failed to download 1Password."
    
    # Install the package
    sudo apt install -y "$tmp_deb" || handle_error "Failed to install 1Password."

    # Clean up
    rm -f "$tmp_deb"
    echo "1Password installed successfully."
}

# Prompt user for each software
selected_packages=()
for pkg in "${!software[@]}"; do
    read -p "Do you want to install ${software[$pkg]}? (y/N): " choice
    case "$choice" in
        [yY]*) selected_packages+=("$pkg") ;;
        *) echo "Skipping ${software[$pkg]}..." ;;
    esac
done

# Install selected packages
if [ ${#selected_packages[@]} -eq 0 ]; then
    echo "No software selected for installation. Exiting."
    exit 0
fi

echo "Installing selected packages: ${selected_packages[*]}"
for package in "${selected_packages[@]}"; do
    case "$package" in
        jetbrains-toolbox) install_jetbrains_toolbox ;;
        github-desktop) install_github_desktop ;;
        discord) install_discord ;;
        google-chrome) install_google_chrome ;;
        1password) install_1password ;;
        *) echo "Unknown package: $package. Skipping." ;;
    esac
done

# Completion message
echo "Selected software installed successfully."
