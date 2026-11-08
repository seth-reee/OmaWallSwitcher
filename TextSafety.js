.pragma library

// Omarchy owns the tooltip's Text element. Neutralize tag delimiters before
// passing filenames or errors to it, so they cannot become rich-text resources.
function tooltip(value) {
    return String(value || "").replace(/</g, "‹").replace(/>/g, "›")
}
