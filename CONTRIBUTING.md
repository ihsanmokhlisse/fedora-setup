# Contributing to FedoraFlow

First off, thank you for considering contributing to FedoraFlow! It's people like you that make the open-source community such a great place.

## 🧠 Our Philosophy

Before submitting a Pull Request, please ensure your changes align with the core philosophy of this project:

1. **Idempotency is King:** Every function must check if a setting is already applied before applying it. Running the script twice should *never* result in duplicated config lines or errors.
2. **Sane Defaults:** We aim for configurations that benefit 95% of users. Niche, highly specific ricing or window manager configurations should be avoided.
3. **Stability First:** We do not break the host OS. (e.g., Use Flatpaks and Toolbox containers instead of installing messy dependencies directly via DNF).

## 🛠️ How to Contribute

### 1. Reporting Bugs
If you find a bug (e.g., a specific module fails on Fedora 40, or a kernel parameter causes issues on AMD hardware), please open an issue using the **Bug Report** template. Include your OS version, hardware specs, and the exact error log (`setup.log`).

### 2. Suggesting Enhancements
Have an idea for a new optimization or a new Profile? Open an issue using the **Feature Request** template. Let's discuss it before you write the code!

### 3. Pull Requests
1. **Fork** the repository.
2. **Create a branch** for your feature (`git checkout -b feat/amazing-feature`).
3. **Write clean Bash:**
   * Use `shellcheck` to lint your code.
   * Use `local` for variables inside functions.
   * Always quote your variables (`"$VAR"`).
4. **Test your changes:** Ensure your code works on a fresh Fedora VM or Toolbox container.
5. **Commit your changes:** Use conventional commits (e.g., `feat: add bluetooth audio optimization`).
6. **Push and open a PR.**

## 📝 Code Style Guide

* Use 4 spaces for indentation (no tabs).
* Use `[[ ]]` instead of `[ ]` for bash conditionals.
* Always redirect noisy output to `/dev/null` or pipe it through `tail` to keep the terminal output clean and beautiful for the user.
* Use the built-in logging functions: `log()`, `warn()`, `err()`.

Example of a good function:
```bash
optimize_something() {
    echo ""
    echo "[+] Optimizing something..."

    local config_file="/etc/something.conf"
    
    if [[ ! -f "$config_file" ]] || ! grep -q "optimized=true" "$config_file"; then
        echo "optimized=true" | sudo tee -a "$config_file" > /dev/null
        echo "  [OK] Something has been optimized"
    else
        echo "  [OK] Something is already optimized"
    fi
}
```

Thank you for helping make Fedora better for everyone!
