# RepoCrypto
This PowerShell module is provided as a rudimentary aid to securing configuration files in shared git repositories without an external Key Vault.

This work is just a wrapper for the excellent [FileCryptography Powershell Module](https://gallery.technet.microsoft.com/scriptcenter/EncryptDecrypt-files-use-65e7ae5d) by Tyler Siegrist.

## Use Case
You have inherited a git repository with configuration files (.properties and .xml) which contain database credentials and other secrets for test and production servers. Your IT organization does not have machinery in place to manage these secrets securely, so they have been kept in the source code repository in plaintext.  The files get packaged (in the clear) with the application before being distributed to each environment.

For example
```
- src
  - main
    -resources
      - log4j.properties
      - application-dev.properties
      - application-cat.properties
      - application-prod.properties
      - config-dev.xml
      - config-cat.xml
      - config-prod.xml
```

You need to:
1. Clean up the repository history
2. Encrypt the files in git
3. Stash the key somewhere safe
4. Decrypt the files in the CI/CD pipelines

## Installation
Clone the module into your `$env:PSModulePath`. 

##### Windows PowerShell
```PowerShell
git clone https://<REPO> "$home\Documents\WindowsPowerShell\Modules"
```
##### Linux PowerShell
```PowerShell
git clone https://<REPO> "$home/.local/share/powershell/Modules"
```

## Using in CI/CD Pipelines
#### Cleaning up existing repositories
If you already have plaintext secrets in a public git repository, you should assume that the resources are already compromised and you need to take steps to create new passwords/keys/users.

See [Cleanup with BFG](#cleanup-with-bfg) for cleaning up a git repository's history.

#### Encrypting Properties in a Git Repository
```PowerShell
# Import the Module
Import-Module posh-repocrypto
$key = New-CryptographyKey -Algorithm AES -AsPlainText

# File patterns.  For example, if our properties files were like this:
#     src/main/resources/application-dev.properties
#     src/main/resources/application-cat.properties
#     src/main/resources/application-prod.properties
#     src/main/resources/config-dev.xml
#     src/main/resources/config-cat.xml
#     src/main/resources/config-prod.xml
$files=@("application*.properties", "config*.xml")

# Optionally, add these patterns to .gitignore to keep
# them from being checked in during development, since
# it's a pain to remove them if they get pushed to a public repo
$files |% { $_ | Out-File -Append .gitignore }

# Recursively encrypt any matching files and remove the originals
foreach($file in $files){
    Get-ChildItem -Recurse $file |% {
        $f = Protect-File $_ -Algorithm AES -KeyAsPlainText $key 

        # if the file was previously in git, remove it from git
        # suppress the error message if the file wasn't in git
        git rm $_.FullName 2> $null

        git add $f.FullName
    }
}

# Dump the crypto key so you can plug it into your pipeline
Write-Output "Crypto Key: $key"

# verify the changes and commit
git commit
```

If your sensitive files were previously committed to git, you should consider [Git Cleanup with BFG](#git-cleanup-with-bfg) to remove them from the history.


#### Decrypting from a Pipeline
You should retain a secure copy of the key somewhere like [KeePassXC](https://keepassxc.org/), [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/). The decrypt step is to simply recurse through your directory tree and decrypt "*.AES" files, passing the `$key` from a Secure Variable or file.
```PowerShell
# Decrypt all AES encrypted files
Get-ChildItem -Recurse "*.AES" |% {
    UnProtect-File $_ -Algorithm AES -KeyAsPlainText $key -RemoveSource
}
```

# Git Cleanup with BFG
If you have a dirty repo, you can use the [bfg repo cleaner](https://rtyley.github.io/bfg-repo-cleaner/) to clean it up.  If your repo was published somewhere like Azure Repos or github, you'll need force push rights on the remote repository.

You'll need Java in your `$env:PATH` to run `bfg`.  BFG assumes that you've got the `HEAD` of your `master` branch the way you want it, and cleans out the history.

```PowerShell
# remove the files from the HEAD revision, if necessary
# you will need to retain a copy of the files somewhere,
# as we are going to completely purge them
# from the repo's history, staging, and Working Tree
$files=@("application*.properties", "config*.xml")
foreach ($file in $files){
    Get-ChildItem -Recurse $file |% {
       git rm $_.FullName 
    }
}

git commit -m "Cleaned up sensitive files before running bfg"

$files |% { bfg --delete-files $_ }
git reflog expire --expire=now --all 
git gc --prune=now --aggressive
```

# Related Links
- [bfg repo cleaner](https://rtyley.github.io/bfg-repo-cleaner/) (github)
- [removing sensitive data from a repo](https://help.github.com/articles/removing-sensitive-data-from-a-repository/) (github)
- [FileCryptography Powershell Module](https://gallery.technet.microsoft.com/scriptcenter/EncryptDecrypt-files-use-65e7ae5d)  (microsoft technet)
