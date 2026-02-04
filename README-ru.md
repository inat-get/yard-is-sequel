# yard-is-sequel

Плагин для YARD, позволяющий документировать модели Sequel.

## Установка и использование

Подключаем гем через `Gemfile`:

```ruby
gem 'yard-is-sequel', '~> 0.8'
```

Или через `.gemspec`:

```ruby
spec.add_development_dependency 'yard-is-sequel', '~> 0.8'
```

Затем включаем его через ключ в командной строке:

```shell
$ yardoc --plugin is-sequel
```

Или в файле `.yardopts`.

