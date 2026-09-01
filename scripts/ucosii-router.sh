#!/bin/bash
# scripts/ucosii-router.sh: Build and run the uC/OS-II router in QEMU

# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QEMU_LOG_FILE="$PROJECT_ROOT/logs/ucosii-router.log"

router_pid() {
    [ -f "$PROJECT_ROOT/$QEMU_ROUTER_PID_FILE" ] || return 1
    cat "$PROJECT_ROOT/$QEMU_ROUTER_PID_FILE"
}

router_running() {
    local pid
    pid=$(router_pid 2>/dev/null) || return 1
    case "$pid" in
        ''|*[!0-9]*) return 1 ;;
    esac
    kill -0 "$pid" 2>/dev/null || return 1
    [ "$(basename "$(readlink -f "/proc/$pid/exe" 2>/dev/null)")" = "qemu-system-aarch64" ]
}

ensure_tap() {
    local tap="$1"
    local bridge="$2"
    local run_user

    bridge_has_tap() {
        local candidate_bridge="$1"
        local candidate_tap="$2"
        brctl show "$candidate_bridge" 2>/dev/null | \
            awk -v tap="$candidate_tap" '
                NR > 1 {
                    for (i = 1; i <= NF; i++) {
                        if ($i == tap) found = 1
                    }
                }
                END { exit(found ? 0 : 1) }
            '
    }

    run_user="$(id -un)"
    if ! ip link show "$tap" >/dev/null 2>&1; then
        info "Creating TAP $tap for $bridge..."
        sudo ip tuntap add dev "$tap" mode tap user "$run_user" \
            || error "Failed to create TAP $tap"
    fi

    sudo ip link set "$tap" up || error "Failed to bring up TAP $tap"

    if ! bridge_has_tap "$bridge" "$tap"; then
        if bridge_has_tap "$BRIDGE_LAN" "$tap" || \
           bridge_has_tap "$BRIDGE_WAN" "$tap"; then
            error "TAP $tap is already attached to another bridge"
        fi
        info "Attaching $tap to $bridge..."
        sudo brctl addif "$bridge" "$tap" \
            || error "Failed to attach $tap to $bridge"
    fi
}

build_router() {
    if [ ! -f "$PROJECT_ROOT/$UCOSII_DIR/Makefile" ]; then
        info "Initializing uC/OS-II git submodule..."
        git -C "$PROJECT_ROOT" submodule update --init --recursive "$UCOSII_DIR" \
            || error "Failed to initialize uC/OS-II submodule at $UCOSII_DIR"
    fi
    [ -f "$PROJECT_ROOT/$UCOSII_DIR/Makefile" ] || \
        error "uC/OS-II source is missing at $UCOSII_DIR"
    info "Building uC/OS-II router image..."
    (cd "$PROJECT_ROOT/$UCOSII_DIR" && make) \
        || error "Failed to build uC/OS-II router image"
}

start_router() {
    local image
    local pid_file
    local -a qemu_args

    if router_running; then
        info "uC/OS-II router is already running."
        return 0
    fi

    pid_file="$PROJECT_ROOT/$QEMU_ROUTER_PID_FILE"
    mkdir -p "$(dirname "$pid_file")"
    rm -f "$pid_file"
    image="$PROJECT_ROOT/$UCOSII_DIR/bin/kernel.elf"
    [ -x "$image" ] || build_router

    ensure_tap "$QEMU_LAN_TAP" "$BRIDGE_LAN"
    ensure_tap "$QEMU_WAN_TAP" "$BRIDGE_WAN"

    qemu_args=(
        qemu-system-aarch64
        -M virt,gic_version=2
        -nographic
        -serial mon:stdio
        -cpu "$QEMU_ROUTER_CPU"
        -smp 1
        -m "$QEMU_ROUTER_MEMORY"
        -global virtio-mmio.force-legacy=false
        -netdev "tap,id=net0,ifname=$QEMU_LAN_TAP,script=no,downscript=no"
        -device "virtio-net-device,netdev=net0,bus=virtio-mmio-bus.0,mac=52:54:00:12:34:56"
        -netdev "tap,id=net1,ifname=$QEMU_WAN_TAP,script=no,downscript=no"
        -device "virtio-net-device,netdev=net1,bus=virtio-mmio-bus.1,mac=52:54:00:65:43:21"
        -kernel "$image"
    )

    info "Starting uC/OS-II router in QEMU..."
    # Detach QEMU from the invoking shell/session.  Without this, the
    # terminal runner can send its cleanup signal to the background router.
    nohup setsid "${qemu_args[@]}" >> "$QEMU_LOG_FILE" 2>&1 < /dev/null &
    echo "$!" > "$pid_file"
    sleep 3

    router_running || {
        warn "uC/OS-II router exited during startup."
        tail -n 80 "$QEMU_LOG_FILE"
        error "Failed to start uC/OS-II router"
    }
    print_status "uC/OS-II router" "RUNNING (LAN, WAN)"
}

stop_router() {
    local pid

    if ! router_running; then
        rm -f "$PROJECT_ROOT/$QEMU_ROUTER_PID_FILE"
        warn "uC/OS-II router is not running."
        return 0
    fi

    pid=$(router_pid)
    info "Stopping uC/OS-II router (PID $pid)..."
    kill "$pid" 2>/dev/null || true
    for _ in {1..20}; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
    done
    if kill -0 "$pid" 2>/dev/null; then
        warn "Router did not stop gracefully; terminating PID $pid."
        kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PROJECT_ROOT/$QEMU_ROUTER_PID_FILE"
}

remove_tap() {
    local tap="$1"
    if ip link show "$tap" >/dev/null 2>&1; then
        info "Removing TAP $tap..."
        sudo ip link delete "$tap" || error "Failed to remove TAP $tap"
    fi
}

status_router() {
    if router_running; then
        print_status "uC/OS-II router" "RUNNING (PID $(router_pid))"
        return 0
    fi
    print_status "uC/OS-II router" "STOPPED"
    return 1
}

case "${1:-}" in
    start)
        build_router
        start_router
        ;;
    stop)
        stop_router
        ;;
    cleanup)
        stop_router
        remove_tap "$QEMU_LAN_TAP"
        remove_tap "$QEMU_WAN_TAP"
        ;;
    status)
        status_router
        ;;
    *)
        echo "Usage: $0 {start|stop|cleanup|status}"
        exit 2
        ;;
esac
