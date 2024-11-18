# Infra.mac

## 事前準備

- Install Homebrew
  ```shell
  $ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

- Install Ansible
  ```shell
  $ brew install ansible
  ```


## exec

```shell
# dry-run
$ ansible-playbook localhost-mac.yml --diff --check
$ ansible-playbook localhost-mac.yml
```


## asdf

```shell
$ asdf list-all java
$ asdf install java latest:corretto-21
$ asdf local java latest:corretto-21
```

## Change the Screenshot Location (macOS Mojave or Newer)
- Hold the Shift + Command + 5 keys to open the Screenshot toolbar.
- Click Options and choose where to save your screenshots.
