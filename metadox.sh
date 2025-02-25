#!/bin/bash

# Prints tool usage and a quick guide on how to use the tool.
if [ "$#" -ne 1 ]; then
cat << "EOF"
                _            _           
               | |          | |          
 _ __ ___   ___| |_ __ _  __| | _____  __
| '_ ` _ \ / _ \ __/ _` |/ _` |/ _ \ \/ /
| | | | | |  __/ || (_| | (_| | (_) >  < 
|_| |_| |_|\___|\__\__,_|\__,_|\___/_/\_\
EOF
    echo ""
    echo "Downloads files from websites in scope, identifies metadata leakage, and creates a report of what it finds."
    echo ""
    echo "Usage: $0 <web.txt>"
    echo ""
    echo ">> readme <<"
    echo "Has someone ran Beholder? Provide the filepath to web.txt or create your own with the IP/hostnames in scope."
    echo "This script is looking for a fairly small list of file formats. Add/remove extensions to lines 30 & 64 as needed!"
    exit 1
fi

IP_LIST=$1
OUTPUT_FILES="Files"
REPORTS_DIR="Reports"

# File extensions to search for with feroxbuster. Adjust as needed then skip to line 48 to add the file extensions there as well.
EXTENSIONS="odt,ods,odp,pptx,ppt,xlsx,xls,docx,doc,jpg,jpeg,png,gif,tiff,bmp,mp4,mov,avi,bak,zip,tar.gz"

# Directories to store the results.
mkdir -p "$OUTPUT_FILES"
mkdir -p "$REPORTS_DIR"

# Loop through each IP/hostname
while read -r ip; do
    echo "[+] Scanning $ip for specific file types..."

    # Sets the naming standard for the report file as IP/hostname_report.html
    REPORT_FILE="$REPORTS_DIR/${ip}_report.html"

    # Add some flare to the report so it's not a plain HTML page.
    echo "<html><head><title>Metadata Report - $ip</title>" > "$REPORT_FILE"
    echo "<style>
            body { font-family: Arial, sans-serif; text-align: center; background-color: #f4f4f4; }
            .container { width: 80%; margin: 20px auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0px 0px 10px rgba(0, 0, 0, 0.1); }
            h1 { color: #333; }
            table { width: 100%; border-collapse: collapse; margin-top: 20px; }
            th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
            th { background-color: #007bff; color: white; }
            tr:nth-child(even) { background-color: #f2f2f2; }
          </style></head><body>" >> "$REPORT_FILE"

    echo "<div class='container'>" >> "$REPORT_FILE"
    echo "<h1>Metadata Report for $ip</h1>" >> "$REPORT_FILE"
    echo "<table>" >> "$REPORT_FILE"
    echo "<tr><th>Filename</th><th>File Type</th><th>File Size</th><th>Create Date</th><th>Modify Date</th><th>Author</th><th>Title</th><th>Keywords</th><th>Comment</th></tr>" >> "$REPORT_FILE"

    # Run feroxbuster to looking for the specific file types. Make changes in lines 30 and 64 to add or remove any other extensions you find (or think of). 
    # Depending on the MP, adjust to/from http to https.
    feroxbuster -u "http://$ip" -x "$EXTENSIONS" | tee "ferox_$ip.txt"

    # Identifies the URLs of the discovered files. If you've added additional extensions in line 30 add them here as well using the same format. 
    # Depending on the MP, adjust to/from http to https. 
    grep -Eo "http://$ip[^ ]+\.(odt|ods|odp|pptx|ppt|xlsx|xls|docx|doc|jpg|jpeg|png|gif|tiff|bmp|mp4|mov|avi|bak|zip|tar.gz)" "ferox_$ip.txt" > "files_$ip.txt"

    # Downloads the files. This will also make a files_IP.txt file that lists everything feroxbuster found. 
    if [ -s "files_$ip.txt" ]; then
        echo "[+] Downloading files from $ip..."
        mkdir -p "$OUTPUT_FILES/$ip"
        wget -P "$OUTPUT_FILES/$ip" -i "files_$ip.txt"

        # Run exiftool on the downloaded files and add it to an to HTML file.
        for file in "$OUTPUT_FILES/$ip"/*; do
            if [ -f "$file" ]; then
                echo "[+] Extracting metadata from: $file"
                metadata=$(exiftool -FileName -FileType -FileSize -CreateDate -ModifyDate -Author -Title -Keywords -Comment "$file")
                
                # Fields to extract from the exiftool analysis.
                filename=$(echo "$metadata" | grep "File Name" | awk -F': ' '{print $2}')
                filetype=$(echo "$metadata" | grep "File Type" | awk -F': ' '{print $2}')
                filesize=$(echo "$metadata" | grep "File Size" | awk -F': ' '{print $2}')
                createdate=$(echo "$metadata" | grep "Create Date" | awk -F': ' '{print $2}')
                modifydate=$(echo "$metadata" | grep "Modify Date" | awk -F': ' '{print $2}')
                author=$(echo "$metadata" | grep "Author" | awk -F': ' '{print $2}')
                title=$(echo "$metadata" | grep "Title" | awk -F': ' '{print $2}')
                keywords=$(echo "$metadata" | grep "Keywords" | awk -F': ' '{print $2}')
                comment=$(echo "$metadata" | grep "Comment" | awk -F': ' '{print $2}')

                # Appends metadata to the HTML report.
                echo "<tr><td>$filename</td><td>$filetype</td><td>$filesize</td><td>$createdate</td><td>$modifydate</td><td>$author</td><td>$title</td><td>$keywords</td><td>$comment</td></tr>" >> "$REPORT_FILE"
            fi
        done
    else
        echo "[-] No downloadable files found on $ip."
        echo "<tr><td colspan='9' style='text-align:center;'>No files found.</td></tr>" >> "$REPORT_FILE"
    fi

    # Closing tags to finish up the creation of the HTML file.
    echo "</table></div></body></html>" >> "$REPORT_FILE"

    echo "[+] $ip has finished processing. Reports were saved to '$REPORT_FILE'."
done < "$IP_LIST"

echo "[+] Finished! Check the '$REPORTS_DIR' directory for any findings and don't forget to add them to the share. Good luck, have fun!"