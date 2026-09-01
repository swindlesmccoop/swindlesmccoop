#!/usr/bin/env bash
# Merge the A70x's split HID mouse interfaces into one virtual pointer.
# Port-independent: resolves by by-id / name. Product ID is not hard-coded —
# Bloody software can change 09da:xxxx (fec1, 16cb, …) without breaking this.
set -euo pipefail

VENDOR=09da
PRIMARY_BY_ID=/dev/input/by-id/usb-COMPANY_USB_Device-if01-event-mouse
SECONDARY_BY_ID=/dev/input/a70x-secondary
SECONDARY_NAME='COMPANY  USB Device  Mouse'

find_primary() {
  if [[ -e "$PRIMARY_BY_ID" ]]; then
    printf '%s\n' "$PRIMARY_BY_ID"
    return 0
  fi
  # Fallback: vendor 09da + buttons + relative axes (real mouse iface)
  local d vendor rel key
  for d in /sys/class/input/event*; do
    [[ -e "$d/device/name" ]] || continue
    vendor=$(<"$d/device/id/vendor")
    [[ "$vendor" == "$VENDOR" ]] || continue
    rel=$(<"$d/device/capabilities/rel")
    key=$(<"$d/device/capabilities/key")
    [[ "$rel" != "0" && "$key" != "0" ]] || continue
    printf '/dev/input/%s\n' "$(basename "$d")"
    return 0
  done
  return 1
}

find_secondary() {
  if [[ -e "$SECONDARY_BY_ID" ]]; then
    printf '%s\n' "$SECONDARY_BY_ID"
    return 0
  fi
  local d name vendor
  for d in /sys/class/input/event*; do
    [[ -e "$d/device/name" ]] || continue
    name=$(<"$d/device/name")
    [[ "$name" == "$SECONDARY_NAME" ]] || continue
    vendor=$(<"$d/device/id/vendor")
    [[ "$vendor" == "$VENDOR" ]] || continue
    printf '/dev/input/%s\n' "$(basename "$d")"
    return 0
  done
  return 1
}

echo "Waiting for A70x primary + secondary interfaces..." >&2
primary="" secondary=""
for _ in $(seq 1 60); do
  primary=$(find_primary || true)
  secondary=$(find_secondary || true)
  if [[ -n "$primary" && -n "$secondary" && -e "$primary" && -e "$secondary" ]]; then
    break
  fi
  sleep 0.5
  primary="" secondary=""
done

if [[ -z "$primary" || -z "$secondary" ]]; then
  echo "A70x interfaces not found (primary='$primary' secondary='$secondary')" >&2
  exit 1
fi

# Use the live product ID on the virtual device (survives Bloody re-flash IDs)
product=$(cat "/sys/class/input/$(basename "$(readlink -f "$primary")")/device/id/product" 2>/dev/null || echo 16cb)

echo "Primary:   $primary -> $(readlink -f "$primary")" >&2
echo "Secondary: $secondary -> $(readlink -f "$secondary")" >&2
echo "device-id: 09da:$product" >&2

# grab: hide the split nodes from libinput/KWin
# persist=exit: on unplug, exit so systemd restarts us and we re-resolve paths
exec evsieve \
  --input "$primary" grab persist=exit \
  --input "$secondary" grab persist=exit \
  --output name="A70x Merged Mouse" device-id="09da:$product"
