# Infra.mac

## 事前準備

- Homebrewのインストール
  ```shell
  $ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

- Ansibleのインストール
  ```shell
  $ brew install ansible
  ```


## 実行

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
