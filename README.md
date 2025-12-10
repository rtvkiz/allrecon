# allrecon

A powerful web reconnaissance automation tool that combines subdomain enumeration and directory discovery for comprehensive security assessments with intelligent endpoint analysis.

## Overview

**allrecon** streamlines the reconnaissance phase of security testing by intelligently orchestrating two industry-standard tools:
- **[Subfinder](https://github.com/projectdiscovery/subfinder)** - Fast subdomain discovery
- **[dirsearch](https://github.com/maurosoria/dirsearch)** - Web path scanner for finding directories and files

The tool automatically discovers subdomains, scans them for accessible endpoints, filters results by HTTP status codes, identifies interesting/sensitive endpoints using smart pattern matching, and generates organized reports - all from a single command.

## Features

### Core Capabilities
- **Input Validation** - Validates domain format before scanning
- **Parallel Processing** - Configurable concurrent scans for better performance
- **Flexible Filtering** - Capture multiple HTTP status codes (200, 201, 301, 302, etc.)
- **Timeout Protection** - Prevents hanging on unresponsive hosts
- **Auto-Update** - Automatically update tools before scanning (optional)
- **Color-Coded Output** - Clear visual feedback during execution
- **Comprehensive Logging** - Detailed logs for troubleshooting
- **Progress Tracking** - Real-time scan progress indicators
- **Environment Variables** - Configure defaults without command-line flags
- **Detailed Summary** - Complete scan statistics and file locations
- **Duplicate Removal** - Automatic deduplication and sorting of results

### Smart Intelligence (NEW in v2.1)
- **Categorized Results** - Separate files for 2xx, 3xx, 4xx, and 5xx responses
- **Smart Filtering** - AI-powered pattern matching to identify interesting endpoints
- **Priority Scoring** - Endpoints ranked by potential security impact
- **Category Detection** - Automatically identifies:
  - Admin panels (wp-admin, cpanel, administrator)
  - API endpoints (REST, GraphQL, Swagger)
  - Authentication systems (login, oauth, JWT)
  - Configuration files (.env, config, settings)
  - Database interfaces (phpmyadmin, adminer)
  - Backup files (backup, .bak, .sql)
  - Upload functionality
  - Debug/test environments
  - Sensitive files (.git, .svn, credentials)

## Installation

### Prerequisites

- Bash 4.0 or higher
- Go (for subfinder)
- Python 3 (for dirsearch)

### Step 1: Install Dependencies

**Install Subfinder:**
```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
```

**Install Dirsearch:**
```bash
pip3 install dirsearch
```

**Ensure tools are in your PATH:**
```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$PATH:$HOME/go/bin"
```

### Step 2: Clone and Setup allrecon

```bash
# Clone the repository
git clone https://github.com/rtvkiz/allrecon.git
cd allrecon

# Make executable
chmod +x allrecon.sh

# Optionally, add to PATH
sudo ln -s "$(pwd)/allrecon.sh" /usr/local/bin/allrecon
```

## Usage

### Basic Usage

```bash
./allrecon.sh example.com
```

### Advanced Usage

```bash
# Scan with verbose logging and custom HTTP codes
./allrecon.sh -v -c "200,201,301,302" example.com

# Use custom output directory with 10 parallel scans
./allrecon.sh -o /tmp/scans --parallel 10 target.com

# Set timeout to 10 minutes and keep previous results
./allrecon.sh --timeout 600 --no-cleanup example.com

# Combine multiple options
./allrecon.sh -v -c "200,204" -p 15 -t 300 -o ./results example.com
```

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-o, --output DIR` | Output directory | `output` |
| `-c, --codes CODES` | HTTP status codes to capture (comma-separated) | `200,201,204,301,302` |
| `-p, --parallel NUM` | Maximum parallel dirsearch processes | `5` |
| `-t, --timeout SEC` | Timeout for each dirsearch scan (seconds) | `300` |
| `-v, --verbose` | Enable verbose logging | `false` |
| `-u, --update` | Update subfinder and dirsearch before scanning | `false` |
| `-s, --smart` | Enable smart filtering for interesting endpoints | `true` |
| `--no-smart` | Disable smart filtering | - |
| `--no-cleanup` | Don't remove previous scan results | `false` |
| `-h, --help` | Display help message | - |
| `--version` | Display version information | - |

### Environment Variables

Configure default behavior without command-line flags:

```bash
export ALLRECON_OUTPUT_DIR="/var/scans"
export ALLRECON_HTTP_CODES="200,301,302,403"
export ALLRECON_MAX_PARALLEL="10"
export ALLRECON_TIMEOUT="600"
export ALLRECON_VERBOSE="true"
export ALLRECON_AUTO_UPDATE="true"
export ALLRECON_SMART_FILTER="true"
```

## Output Structure

```
output/
└── example.com/
    ├── hosts.txt                    # Discovered subdomains
    ├── final_all.txt                # All endpoints (combined)
    ├── final_2xx_success.txt        # Success responses (200, 201, 204, etc.)
    ├── final_3xx_redirects.txt      # Redirect responses (301, 302, etc.)
    ├── final_4xx_client_errors.txt  # Client errors (403, 404, etc.)
    ├── final_5xx_server_errors.txt  # Server errors (500, 502, etc.)
    ├── interesting.txt              # 🎯 High-priority findings (smart filter)
    ├── scan.log                     # Detailed execution log
    └── dir/                         # Individual scan results per subdomain
        ├── sub1.example.com.txt
        ├── sub2.example.com.txt
        └── ...
```

### Output Files Explained

| File | Description |
|------|-------------|
| `hosts.txt` | List of all discovered subdomains from subfinder |
| `final_all.txt` | All endpoints across all HTTP status codes |
| `final_2xx_success.txt` | **Successful requests** - Working endpoints (200, 201, 204, etc.) |
| `final_3xx_redirects.txt` | **Redirects** - URLs with redirects (301, 302, 307, etc.) |
| `final_4xx_client_errors.txt` | Client errors (403 Forbidden, 404 Not Found, etc.) |
| `final_5xx_server_errors.txt` | Server errors (500, 502, 503, etc.) |
| **`interesting.txt`** | **🎯 HIGH PRIORITY** - Endpoints matching security-relevant patterns (admin, auth, config, sensitive files) with score and categories |
| `scan.log` | Timestamped execution log with detailed information |
| `dir/*.txt` | Individual dirsearch results for each subdomain |

## Examples

### Example 1: Quick Bug Bounty Recon with Auto-Update

```bash
./allrecon.sh -u bugcrowd.com
```

**Output:**
```
[INFO] Updating reconnaissance tools...
[INFO] Updating subfinder...
[SUCCESS] Subfinder updated successfully
[INFO] Updating dirsearch...
[SUCCESS] Dirsearch updated successfully

[INFO] Checking dependencies...
[SUCCESS] All dependencies found
[INFO] Starting reconnaissance for: bugcrowd.com

[INFO] Starting subdomain enumeration for: bugcrowd.com
[SUCCESS] Found 127 subdomains

[INFO] Starting directory scans on 127 hosts (max 5 parallel)
[INFO] [1/127] Scanning: www.bugcrowd.com
[INFO] [2/127] Scanning: api.bugcrowd.com
...
[SUCCESS] All directory scans completed

[INFO] Aggregating results for HTTP codes: 200,201,204,301,302
[SUCCESS] Found 1547 endpoints (892 unique) from 127 scan results
[INFO] Status code breakdown:
  2xx Success:       412 endpoints
  3xx Redirects:     280 endpoints
  4xx Client Errors: 0 endpoints
  5xx Server Errors: 0 endpoints
[INTERESTING] Found 47 interesting endpoints (see interesting.txt)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                        SCAN SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Target Domain:       bugcrowd.com
Subdomains Found:    127
Hosts Scanned:       127
HTTP Status Codes:   200,201,204,301,302

ENDPOINTS DISCOVERED:
  Total Unique:        892
  ├─ 2xx Success:      412
  ├─ 3xx Redirects:    280
  ├─ 4xx Client Error: 0
  └─ 5xx Server Error: 0

  🎯 Interesting:      47 (HIGH PRIORITY)

OUTPUT FILES:
  Main Directory:      output/bugcrowd.com
  ├─ Subdomains:       hosts.txt (127)
  ├─ All Endpoints:    final_all.txt (892)
  ├─ Success (2xx):    final_2xx_success.txt (412)
  ├─ Redirects (3xx):  final_3xx_redirects.txt (280)
  ├─ 🎯 Interesting:   interesting.txt (47) ⭐
  ├─ Scan Details:     dir/ (127 files)
  └─ Log File:         scan.log

Scan completed at:   2025-12-10 11:15:32
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[INTERESTING] Top 10 Interesting Endpoints (of 47):
  [10] [admin sensitive] https://admin.bugcrowd.com/login
  [9] [config api] https://api.bugcrowd.com/v3/config
  [8] [backup] https://backup.bugcrowd.com/archive.zip
  ...
```

### Example 2: Large-Scale Parallel Scanning with Smart Filter

```bash
# Scan with aggressive parallelization and all HTTP codes
./allrecon.sh -p 20 -t 180 -v -c "200,201,204,301,302,403" example.com
```

### Example 3: Security Audit with Interesting Findings

```bash
# Auto-update tools, capture multiple codes, focus on interesting endpoints
./allrecon.sh -u -v -c "200,301,302,403,500" example.com

# View only high-priority findings
cat output/example.com/interesting.txt
```

### Example 4: Integration with Other Tools

```bash
# Use results with other security tools
./allrecon.sh target.com

# Feed endpoints to nuclei
cat output/target.com/final.txt | nuclei -t vulnerabilities/

# Check for subdomain takeover
cat output/target.com/hosts.txt | subjack -w -
```

## Performance Tips

1. **Adjust Parallelization**: Increase `-p` value for faster scans (but respect rate limits)
   ```bash
   ./allrecon.sh -p 10 target.com  # 10 concurrent scans
   ```

2. **Set Appropriate Timeouts**: Reduce timeout for known-fast targets
   ```bash
   ./allrecon.sh -t 120 target.com  # 2-minute timeout
   ```

3. **Use Verbose Mode for Long Scans**: Monitor progress in real-time
   ```bash
   ./allrecon.sh -v target.com
   ```

4. **Reuse Previous Results**: Use `--no-cleanup` to append to existing scans
   ```bash
   ./allrecon.sh --no-cleanup target.com
   ```

## Troubleshooting

### Common Issues

**Issue: "Command not found: subfinder"**
```bash
# Solution: Ensure Go bin is in PATH
export PATH="$PATH:$HOME/go/bin"
source ~/.bashrc
```

**Issue: "Invalid domain format"**
```bash
# Solution: Use proper domain format (no http://, no paths)
./allrecon.sh example.com          # ✓ Correct
./allrecon.sh https://example.com  # ✗ Wrong
./allrecon.sh example.com/path     # ✗ Wrong
```

**Issue: Scans timing out frequently**
```bash
# Solution: Increase timeout value
./allrecon.sh -t 600 target.com  # 10-minute timeout
```

**Issue: No endpoints found**
```bash
# Solution: Check scan logs for errors
cat output/target.com/scan.log
```

### Debugging

Enable verbose mode and check logs:
```bash
./allrecon.sh -v target.com
cat output/target.com/scan.log
```

## Use Cases

- **Bug Bounty Hunting** - Quickly discover attack surface
- **Penetration Testing** - Initial reconnaissance phase
- **Asset Discovery** - Enumerate organization's web presence
- **Security Audits** - Identify exposed endpoints
- **Continuous Monitoring** - Automated periodic scans

## Security Considerations

- **Authorization**: Only scan domains you have permission to test
- **Rate Limiting**: Adjust parallelization to respect target infrastructure
- **Disclosure**: Follow responsible disclosure practices
- **Legal Compliance**: Ensure compliance with local laws and regulations

## Changelog

### Version 2.1 (Current - December 2025)
**Major Intelligence Update**
- ⭐ **Auto-Update Functionality** - Automatically update subfinder and dirsearch (`-u` flag)
- 🎯 **Smart Endpoint Detection** - Pattern-based identification of interesting/sensitive endpoints
- 📊 **Categorized Results** - Separate files for 2xx, 3xx, 4xx, 5xx status codes
- 🔍 **Priority Scoring** - Endpoints ranked by security impact (admin=10, sensitive=10, config=9, etc.)
- 🏷️ **Category Tagging** - Auto-labels endpoints (admin, api, auth, config, database, backup, etc.)
- 📈 **Enhanced Summary** - Visual breakdown of findings by status code and category
- 🎨 **New Color Coding** - Magenta highlights for interesting findings
- 🔧 **New CLI Options** - `--update`, `--smart`, `--no-smart` flags
- 📝 **Interesting.txt Output** - Dedicated file for high-priority findings with scores

**Pattern Categories Detected:**
- Admin Panels - cpanel, wp-admin, administrator, plesk
- APIs - GraphQL, REST, Swagger, OpenAPI endpoints
- Authentication - OAuth, SSO, SAML, JWT, login portals
- Configuration - .env files, config files, settings
- Databases - phpMyAdmin, Adminer, database interfaces
- Backups - .bak, .sql, backup archives
- Uploads - File upload endpoints
- Debug/Test - Staging environments, debug consoles
- Sensitive Files - .git, .svn, credentials

### Version 2.0 (November 2025)
- Added input validation and domain format checking
- Implemented parallel processing with configurable limits
- Added timeout protection for scans
- Introduced flexible HTTP status code filtering
- Added color-coded output and progress tracking
- Implemented comprehensive logging system
- Added environment variable support
- Created detailed scan summary reports
- Improved error handling and user feedback
- Added duplicate removal and result sorting
- Implemented command-line argument parsing
- Added help and version information

### Version 1.0 (Original)
- Basic subdomain enumeration
- Sequential directory scanning
- HTTP 200 filtering only
- Simple text output

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is open source. Please check the repository for license details.

## Credits

Built on top of:
- [Subfinder](https://github.com/projectdiscovery/subfinder) by ProjectDiscovery
- [dirsearch](https://github.com/maurosoria/dirsearch) by Mauro Soria

## Author

[rtvkiz](https://github.com/rtvkiz)

## Support

If you find this tool useful, please star the repository!

For issues or questions:
- Open an issue on [GitHub](https://github.com/rtvkiz/allrecon/issues)
- Check the troubleshooting section above
- Review the scan logs for detailed error information
