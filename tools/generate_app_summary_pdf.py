from pathlib import Path


PAGE_WIDTH = 595.28  # A4 portrait in points
PAGE_HEIGHT = 841.89
MARGIN = 42
FONT_SIZE = 10.5
LEADING = 14


def escape_pdf_text(text: str) -> str:
    return (
        text.replace("\\", "\\\\")
        .replace("(", "\\(")
        .replace(")", "\\)")
    )


def wrap_text(text: str, max_chars: int) -> list[str]:
    words = text.split()
    if not words:
        return [""]
    lines: list[str] = []
    current = words[0]
    for word in words[1:]:
        candidate = f"{current} {word}"
        if len(candidate) <= max_chars:
            current = candidate
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def build_lines() -> list[tuple[str, str]]:
    items: list[tuple[str, str]] = []

    def heading(text: str) -> None:
        items.append(("heading", text))

    def body(text: str) -> None:
        items.append(("body", text))

    def bullet(text: str) -> None:
        items.append(("bullet", text))

    def note(text: str) -> None:
        items.append(("note", text))

    heading("App Summary")
    body(
        "This Flutter app is a personal productivity planner that combines tasks, habits, journaling, "
        "calendar planning, and profile progression in one mobile-first interface."
    )
    body(
        "It stores app data locally with Hive, includes local notifications, and exposes a lightweight "
        "in-app AI companion with scripted guidance flows."
    )

    heading("Who It Is For")
    body(
        "Primary persona inferred from repo workflows: an individual user managing personal tasks, daily "
        "routines, reflections, and progress on a single device."
    )

    heading("What It Does")
    bullet("Captures tasks quickly in Inbox, then organizes them into multiple task lists.")
    bullet("Shows dated tasks in a calendar view with pending/completed breakdowns.")
    bullet("Tracks habits with streaks, lives, daily completion, and XP/coin rewards.")
    bullet("Stores journal entries with text plus optional image attachments.")
    bullet("Builds a daily plan by selecting tasks that fit available minutes and urgency.")
    bullet("Displays profile stats, achievements, productivity charts, and an in-app reward store.")
    bullet("Provides a local AI companion chat with preset prompts for planning, motivation, and reflection.")

    heading("How It Works")
    bullet(
        "UI layer: Flutter Material app with bottom navigation for Tools, Calendar, AI, and Profile."
    )
    bullet(
        "State layer: `AppState` (`ChangeNotifier` via Provider) owns lists, habits, journal entries, "
        "achievements, XP, coins, and scheduling logic."
    )
    bullet(
        "Persistence: Hive boxes store auth/session, task lists, habits, journal entries, achievements, "
        "and settings; main bootstraps Hive and registers adapters."
    )
    bullet(
        "Security: a Hive AES key is generated/read from `flutter_secure_storage`; passwords are hashed "
        "with SHA-256 in `AuthService`."
    )
    bullet(
        "Services: `NotificationService` initializes local notifications; no active remote API/data service "
        "integration was found in repo code."
    )
    note("Backend/API: Not found in repo.")

    heading("How To Run")
    bullet("Install Flutter SDK compatible with Dart `^3.7.2`.")
    bullet("From repo root, run: `flutter pub get`.")
    bullet("Start the app on a target device/emulator: `flutter run`.")
    bullet("Platform folders for Android, iOS, Linux, macOS, Web, and Windows are present in the repo.")

    return items


def estimate_height(items: list[tuple[str, str]]) -> int:
    used = 0
    for kind, text in items:
        if kind == "heading":
            used += 20
        elif kind == "body":
            used += len(wrap_text(text, 88)) * LEADING + 2
        elif kind == "bullet":
            used += len(wrap_text(text, 82)) * LEADING
        elif kind == "note":
            used += len(wrap_text(text, 88)) * LEADING
    return used


def render_content(items: list[tuple[str, str]]) -> str:
    lines: list[str] = []
    y = PAGE_HEIGHT - MARGIN

    def text_line(x: float, y_pos: float, font: str, size: float, text: str) -> None:
        lines.append(f"BT /{font} {size} Tf 1 0 0 1 {x:.2f} {y_pos:.2f} Tm ({escape_pdf_text(text)}) Tj ET")

    text_line(MARGIN, y, "F2", 21, "App Summary")
    y -= 24
    lines.append(
        f"{MARGIN:.2f} {y:.2f} {PAGE_WIDTH - 2 * MARGIN:.2f} 1 re S"
    )
    y -= 18

    for kind, text in items[1:]:
        if kind == "heading":
            text_line(MARGIN, y, "F2", 13, text)
            y -= 18
        elif kind == "body":
            for row in wrap_text(text, 88):
                text_line(MARGIN, y, "F1", FONT_SIZE, row)
                y -= LEADING
            y -= 2
        elif kind == "bullet":
            wrapped = wrap_text(text, 82)
            text_line(MARGIN + 2, y, "F2", 10, "-")
            for index, row in enumerate(wrapped):
                text_line(MARGIN + 14, y, "F1", FONT_SIZE, row)
                y -= LEADING
                if index == 0 and len(wrapped) == 0:
                    break
        elif kind == "note":
            for row in wrap_text(text, 88):
                text_line(MARGIN, y, "F2", 10, row)
                y -= LEADING

    return "\n".join(lines) + "\n"


def build_pdf_bytes(content_stream: bytes) -> bytes:
    objects: list[bytes] = []
    objects.append(b"<< /Type /Catalog /Pages 2 0 R >>")
    objects.append(b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
    page_object = (
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.2f %.2f] "
        "/Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> "
        "/Contents 6 0 R >>"
    ) % (PAGE_WIDTH, PAGE_HEIGHT)
    objects.append(page_object.encode("ascii"))
    objects.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    objects.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>")
    objects.append(
        b"<< /Length %d >>\nstream\n%bendstream" % (len(content_stream), content_stream)
    )

    pdf = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]
    for index, obj in enumerate(objects, start=1):
        offsets.append(len(pdf))
        pdf.extend(f"{index} 0 obj\n".encode("ascii"))
        pdf.extend(obj)
        pdf.extend(b"\nendobj\n")

    xref_pos = len(pdf)
    pdf.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    pdf.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        pdf.extend(f"{offset:010d} 00000 n \n".encode("ascii"))
    pdf.extend(
        (
            "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n"
            % (len(objects) + 1, xref_pos)
        ).encode("ascii")
    )
    return bytes(pdf)


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    out_dir = repo_root / "output" / "pdf"
    out_dir.mkdir(parents=True, exist_ok=True)
    tmp_dir = repo_root / "tmp" / "pdfs"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    items = build_lines()
    estimated = estimate_height(items)
    available = PAGE_HEIGHT - (MARGIN * 2) - 30
    if estimated > available:
        raise RuntimeError(f"Content exceeds one page: estimated {estimated} > available {available}")

    content = render_content(items).encode("latin-1", errors="replace")
    pdf_bytes = build_pdf_bytes(content)
    output_path = out_dir / "app_summary_one_pager.pdf"
    output_path.write_bytes(pdf_bytes)
    print(output_path)


if __name__ == "__main__":
    main()
