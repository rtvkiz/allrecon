# allrecon
Reconnaissance tool build on existing efficient tools  - subfinder and dirsearch. It combines the power of these tools and let you retrieve only necessary results.

## Functionality
allrecon helps you list all the subdomains using subfinder and retrieves only valid accessible directory endpoints from all those subdomains. It also organize the structure of folders in an efficient way, which can be leveraged for bug bounty purposes.

## Installation
1. Clone the repo
2. Install Dirsearch and Subfinder if not installed already and add them to your system path
3. All recon will not work untill you have added these tools to system path
4. Give executable permission to file - chmod +x allrecon.sh

## Usage
./allrecon.sh \<domain\>

## Result
A output folder will be created, which will have different subfolders based on the domains, and each sub directory will have hosts.txt file with all subdomains and a final.txt with only valid 200 Ok response directory URL
