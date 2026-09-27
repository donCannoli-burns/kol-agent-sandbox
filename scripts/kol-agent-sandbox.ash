// kol-agent-sandbox.ash
//
// KoLmafia-facing scaffold for an agent sandbox.
// File helper paths are relative to KoLmafia's data/ directory.
//
// gCLI:
//   call kol-agent-sandbox.ash install [branch]
//   call kol-agent-sandbox.ash docs [branch]
//   call kol-agent-sandbox.ash snapshot [branch]
//   call kol-agent-sandbox.ash mock
//   call kol-agent-sandbox.ash status [branch]
//   call kol-agent-sandbox.ash help

string ROOT = "kolmafia";
string TEMPLATE = "kol-agent-sandbox/README.html5";
string MOCK_REPO = "https://github.com/loathers/kolmafia-mock.git";
string MOCK_BRANCH = "main";
string NOTICE_MARKER = "data-kolmafia-agent-sandbox-notice";

string safe_branch(string branch) {
    if (branch == "") return "main";
    branch = replace_string(branch, "..", "_");
    branch = replace_string(branch, "/", "__");
    branch = replace_string(branch, "\\", "__");
    branch = replace_string(branch, " ", "-");
    branch = replace_string(branch, "<", "_");
    branch = replace_string(branch, ">", "_");
    branch = replace_string(branch, "\"", "_");
    branch = replace_string(branch, "'", "_");
    return branch;
}

string html_escape(string s) {
    s = replace_string(s, "&", "&amp;");
    s = replace_string(s, "<", "&lt;");
    s = replace_string(s, ">", "&gt;");
    s = replace_string(s, "\"", "&quot;");
    return s;
}

void write_text(string path, string text) {
    buffer_to_file(text.to_buffer(), path);
}

string read_text(string path) {
    buffer b = file_to_buffer(path);
    return b.to_string();
}

string sandbox_path(string branch) {
    return ROOT + "/sandboxes/" + safe_branch(branch);
}

string notice_html(string branch) {
    string b = html_escape(safe_branch(branch));
    return "<aside " + NOTICE_MARKER + "=\"1\" style=\"border:2px solid #ffc857;background:#171c1d;color:#e9f0fa;padding:14px 16px;margin:0 0 18px;border-radius:12px;font-family:system-ui,sans-serif\">"
        + "<strong style=\"color:#ffc857\">AGENT SANDBOX NOTICE</strong>"
        + "<div><b>Sandbox:</b> <code>./kolmafia/sandboxes/" + b + "</code></div>"
        + "<div><b>Live:</b> <code>~/.kolmafia</code></div>"
        + "<div style=\"color:#95a4b8\">Work in the sandbox copy. Never fall through to live KoLmafia because a mock/test path failed.</div>"
        + "</aside>\n";
}

string rendered_template(string branch) {
    string b = safe_branch(branch);
    string source = read_text(TEMPLATE);
    if (source == "") {
        source = "<!doctype html><html><body>{{NOTICE}}<h1>KoL Agent Sandbox</h1><p>Branch: {{BRANCH}}</p></body></html>";
    }
    source = replace_string(source, "{{NOTICE}}", notice_html(b));
    source = replace_string(source, "{{BRANCH}}", html_escape(b));
    source = replace_string(source, "{{SANDBOX}}", "./kolmafia/sandboxes/" + html_escape(b));
    source = replace_string(source, "{{LIVE}}", "~/.kolmafia");
    return source;
}

void write_readme_preserving_existing(string path, string branch) {
    string existing = read_text(path);
    if (existing != "") {
        if (index_of(existing, NOTICE_MARKER) >= 0) return;
        write_text(path + ".pre-agent-sandbox.bak", existing);
        write_text(path, notice_html(branch) + existing);
        return;
    }
    write_text(path, rendered_template(branch));
}

string state_json(string branch) {
    string b = replace_string(safe_branch(branch), "\"", "'");
    string path = replace_string(my_path(), "\"", "'");
    string cls = replace_string(my_class(), "\"", "'");
    return "{\n"
        + "  \"kind\": \"kolmafia-readonly-fixture\",\n"
        + "  \"branch\": \"" + b + "\",\n"
        + "  \"player\": \"" + replace_string(my_name(), "\"", "'") + "\",\n"
        + "  \"player_id\": " + my_id() + ",\n"
        + "  \"class\": \"" + cls + "\",\n"
        + "  \"level\": " + my_level() + ",\n"
        + "  \"path\": \"" + path + "\",\n"
        + "  \"daycount\": " + my_daycount() + ",\n"
        + "  \"adventures\": " + my_adventures() + ",\n"
        + "  \"meat\": " + my_meat() + ",\n"
        + "  \"hp\": " + my_hp() + ",\n"
        + "  \"maxhp\": " + my_maxhp() + ",\n"
        + "  \"mp\": " + my_mp() + ",\n"
        + "  \"maxmp\": " + my_maxmp() + "\n"
        + "}\n";
}

void ensure_docs(string branch) {
    branch = safe_branch(branch);
    string root_readme = ROOT + "/README.html5";
    string branch_root = sandbox_path(branch);

    write_readme_preserving_existing(root_readme, branch);
    write_readme_preserving_existing(branch_root + "/README.html5", branch);

    write_text(ROOT + "/index.html5", rendered_template(branch));
    write_text(branch_root + "/LIVE_LOCATION.txt", "~/.kolmafia\n");
    write_text(branch_root + "/SANDBOX_LOCATION.txt", "./kolmafia/sandboxes/" + branch + "\n");
    write_text(branch_root + "/AGENT_BOUNDARY.txt",
        "SANDBOX ONLY\n"
        + "mirror/ is read-only, work/ is writable.\n"
        + "Never copy settings, sessions, cookies, password hashes, or login material into the sandbox.\n"
        + "A mock/test failure is not permission to fall through to live KoLmafia.\n");
}

void print_help() {
    print("KoL Agent Sandbox", "blue");
    print("  install [branch]  scaffold docs + fixture and install kolmafia-mock", "black");
    print("  docs [branch]     regenerate HTML5 sandbox documentation", "black");
    print("  snapshot [branch] refresh the small read-only state fixture", "black");
    print("  mock              install loathers/kolmafia-mock through KoLmafia git", "black");
    print("  status [branch]   print sandbox/live locations", "black");
    print("  help              show this help", "black");
}

void main(string command) {
    string cmd = command;
    string branch = "main";
    int space = index_of(command, " ");

    if (space >= 0) {
        cmd = substring(command, 0, space);
        branch = substring(command, space + 1);
    }

    branch = safe_branch(branch);

    if (cmd == "" || cmd == "help") {
        print_help();
        return;
    }

    if (cmd == "docs") {
        ensure_docs(branch);
        print("Sandbox docs written under data/" + ROOT + " for branch " + branch + ".", "green");
        return;
    }

    if (cmd == "snapshot") {
        ensure_docs(branch);
        write_text(sandbox_path(branch) + "/fixtures/live-state.json", state_json(branch));
        print("Read-only fixture refreshed for " + branch + ".", "green");
        return;
    }

    if (cmd == "mock") {
        print("Installing " + MOCK_REPO + " (" + MOCK_BRANCH + ") through KoLmafia git...", "blue");
        cli_execute("git checkout " + MOCK_REPO + " " + MOCK_BRANCH);
        return;
    }

    if (cmd == "status") {
        print("LIVE:    ~/.kolmafia", "red");
        print("SANDBOX: ./kolmafia/sandboxes/" + branch, "green");
        print("KoLmafia docs: ~/.kolmafia/data/" + sandbox_path(branch), "blue");
        print("Host bootstrap: ~/.kolmafia/scripts/kol-agent-sandbox/bootstrap-agent-sandbox.sh", "blue");
        return;
    }

    if (cmd == "install") {
        ensure_docs(branch);
        write_text(sandbox_path(branch) + "/fixtures/live-state.json", state_json(branch));
        print("KoLmafia-side scaffold complete.", "green");
        print("Installing kolmafia-mock through KoLmafia git...", "blue");
        cli_execute("git checkout " + MOCK_REPO + " " + MOCK_BRANCH);
        print("For the full read-only mirror, run scripts/kol-agent-sandbox/bootstrap-agent-sandbox.sh from your host shell.", "blue");
        return;
    }

    print("Unknown command: " + cmd, "red");
    print_help();
}
