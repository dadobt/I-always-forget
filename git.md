#### GIT
git log pretty print 
```sh
git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit

Undo the last commit but keep the file changes
git reset HEAD~
