# "pre-commit-git-diff-docx.sh:" Small git (https://git-scm.com/)
# hook. It works in combination with another hook,
# "post-commit-git-diff-docx.sh".
#
# Together, they keep a Markdown (.md) copy of .docx files so that git
# diffs of the .md files show the changes in the document (as .docx
# files are binaries, they produce no diffs that can be checked in
# emails or in the repository's commit page).
#
#
# DEPENDENCIES
#
# post-commit-git-diff-docx.sh
# pandoc (http://pandoc.org/)
#
#
# DETAILS:
#
# This script makes a Markdown format copy (.md) of any .docx files in
# the commit. It then lists the .md file names in a temp file called
# .commit-amend-markdown.
#
# After the commit, the post-commit hook
# "post-commit-git-diff-docx.sh" will check for this file. If it
# exists, it will amend the commit adding the names of the .md files.
#
# The reason why we cannot simply add the .md files here is because
# `git add` adds files to the next commit, not the current one.
#
# This script requires pandoc (http://pandoc.org/) to have been
# installed in the system.

# LICENSE:
# Author: Ramon Casero <rcasero@gmail.com>
# Version: 0.3.0
# Copyright © 2016-2017 University of Oxford
# 
# University of Oxford means the Chancellor, Masters and Scholars of
# the University of Oxford, having an administrative office at
# Wellington Square, Oxford OX1 2JD, UK. 
#
# This file is part of Gerardus.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details. The offer of this
# program under the terms of the License is subject to the License
# being interpreted in accordance with English Law and subject to any
# action against the University of Oxford being under the jurisdiction
# of the English Courts.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Create package.json
npm init -y

# Initialize and Install Husky
npx husky-init
npm i

$preCommitScript = @"
#!/bin/bash

# go to top dir of this project, file names refer to that location
cd `git rev-parse --show-toplevel`

# check whether commit included .docx files that were converted to md
if [ -a .commit-amend-markdown ]
then
    # add md files to commit
    cat .commit-amend-markdown | xargs git add || {
        echo "Git cannot add md files to amend commit";
        exit 1;
    }

    # delete file with list of md files to avoid infinite loop
    rm .commit-amend-markdown
	
	# add .md file by amending commit
	git commit --amend -C HEAD --no-verify || {
		echo "Git cannot amend the commit";
		exit 1;
	}
fi
exit
"@

# Set the pre-commit hook using npx husky
npx husky set .husky/pre-commit "$preCommitScript"

$postCommitScript = @"
#!/bin/bash

# abort commit if pandoc is not installed
pandoc -v >/dev/null 2>&1 || { 
    echo >&2 "I require pandoc to keep track of changes in .docx files but it's not installed. Aborting."; 
    exit 1; 
}

# go to the top directory of this project, because filenames will be
# referred to that location
cd `git rev-parse --show-toplevel`

# delete temp file with list of Mardown files to amend commit
rm -f .commit-amend-markdown

# create a Markdown copy of every .docx file that is committed, excluding deleted files
for file in `git diff --cached --name-only --diff-filter=d | grep "\.docx$"`
do
    # name of Markdown file
    mdfile="${file%.docx}.md"
    echo Creating Markdown copy of "$file"
    #echo "$mdfile"

    # convert .docx file to Markdown
    pandoc "$file" -o "$mdfile" || {
    	echo "Conversion to Markdown failed";
    	exit 1;
    }

    # list the Markdown files that need to be added to the amended
    # commit in the post-commit hook. Note that we cannot `git add`
    # here, because that adds the files to the next commit, not to
    # this one
    echo "$mdfile" >> .commit-amend-markdown

done

# remove the Markdown copy of any file that is to be deleted from the repo
for file in `git diff --cached --name-only --diff-filter=D | grep "\.docx$"`
do
    # name of Markdown file
    mdfile="${file%.docx}.md"
    echo Removing Markdown copy of "$file"

    if [ -e "$mdfile" ]
       then
	   # delete the Markdown file
	   git rm "$mdfile"
	   
	   # list the Markdown files that need to be added to the
	   # amended commit in the post-commit hook. Note that we
	   # cannot `git add` here, because that adds the files to the
	   # next commit, not to this one
	   echo "$mdfile" >> .commit-amend-markdown
    fi

done
"@

npx husky set .husky/post-commit "$postCommitScript"

# Add a .gitignore file
Write-Output "node_modules" > .gitignore

# Make sure Git hooks are enabled
npm pkg set scripts.prepare="husky install"
