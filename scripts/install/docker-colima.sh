#!/usr/bin/env bash
# scripts/install/docker-colima.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_docker_colima() {
    log_info "Installing Docker CLI and Colima..."

    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    # Docker CLI
    if command -v docker &> /dev/null || [[ -f "$bin_dir/docker" ]]; then
        log_info "Docker CLI is already installed."
    else
        log_info "Downloading Docker CLI..."
        # Fetching static binary for ARM64 macOS
        execute_cmd "curl -L -o /tmp/docker.tgz https://download.docker.com/mac/static/stable/aarch64/docker-24.0.7.tgz"
        execute_cmd "tar -xzf /tmp/docker.tgz -C /tmp"
        execute_cmd "mv /tmp/docker/docker $bin_dir/"
        execute_cmd "chmod +x $bin_dir/docker"
        execute_cmd "rm -rf /tmp/docker /tmp/docker.tgz"
    fi

    # Colima
    if command -v colima &> /dev/null || [[ -f "$bin_dir/colima" ]]; then
        log_info "Colima is already installed."
    else
        log_info "Downloading Colima..."
        execute_cmd "curl -L -o $bin_dir/colima https://github.com/abiosoft/colima/releases/latest/download/colima-Darwin-aarch64"
        execute_cmd "chmod +x $bin_dir/colima"
    fi

    # Lima (dependency for Colima)
    if command -v limactl &> /dev/null || [[ -f "$bin_dir/limactl" ]]; then
        log_info "Lima is already installed."
    else
        log_info "Downloading Lima..."
        # Fetch Lima release
        execute_cmd "curl -L -o /tmp/lima.tar.gz https://github.com/lima-vm/lima/releases/download/v0.19.1/lima-0.19.1-Darwin-aarch64.tar.gz"
        execute_cmd "mkdir -p /tmp/lima && tar -xzf /tmp/lima.tar.gz -C /tmp/lima"
        execute_cmd "mv /tmp/lima/bin/* $bin_dir/"
        execute_cmd "rm -rf /tmp/lima /tmp/lima.tar.gz"
    fi

    if [[ "$DRY_RUN" != "true" ]]; then
        add_report_entry "Docker CLI" "$($bin_dir/docker --version | awk '{print $3}' | tr -d ',')" "24.0.7" "Download static binary"
        add_report_entry "Colima" "$($bin_dir/colima version | awk '{print $3}' | head -n 1)" "Latest" "Download release binary"

        # Start and configure Colima
        log_info "Configuring and starting Colima..."
        local cpu="${COLIMA_CPU:-2}"
        local memory="${COLIMA_MEMORY:-4}"
        local disk="${COLIMA_DISK:-50}"

        # Ensure PATH includes new binaries for setup
        export PATH="$bin_dir:$PATH"

        execute_cmd "colima start --cpu $cpu --memory $memory --disk $disk"

        # Set docker context to colima
        execute_cmd "docker context use colima || true"

        # Verify
        if docker info &> /dev/null; then
            log_success "Docker & Colima successfully started and verified."
        else
            log_error "Docker & Colima started, but 'docker info' failed."
        fi
    else
        add_report_entry "Docker CLI" "N/A" "24.0.7" "Download static binary"
        add_report_entry "Colima" "N/A" "Latest" "Download release binary"
        log_info "[DRY-RUN] Would configure and start colima with CPU=${COLIMA_CPU:-2}, MEM=${COLIMA_MEMORY:-4}, DISK=${COLIMA_DISK:-50}"
    fi
}

install_docker_colima
