
#!/bin/bash

echo "\033[0;32mDeploying updates to GitHub...\033[0m"


# Build the project.
echo "start execute hugo cmd"
hugo # if using a theme, replace by `hugo -t <yourtheme>`

# Go To Public folder
cd public
# Add changes to git.
git add .


read -p "Enter commit message: "  message

echo "Welcome $message!"

git commit -m "$message"

echo "commit success!!"

git pull --rebase origin master

echo "sync remote project success!!"


read -r -p "Are You Sure push to GitHub? [Y/n] " input

case $input in
    [yY][eE][sS]|[yY])
		echo "Yes"
		#Push source and build repos.
        git push origin master
		;;

    [nN][oO]|[nN])
		echo "No"
       	;;

    *)
		echo "Invalid input..."
		exit 1
		;;
esac

# Come Back
cd ..

echo "current dir is ${pwd}"

