# yard-is-sequel

YARD plugin for documenting Sequel ORM models.

## Overview

`yard-is-sequel` is a YARD plugin that automatically documents Sequel ORM models by extracting information about database fields, associations, and model definitions directly from your Ruby code. It generates comprehensive documentation without requiring manual annotations for basic Sequel features.

## Features

- **Automatic Field Documentation**: Extracts database column information from Sequel models
- **Association Detection**: Documents `many_to_one`, `one_to_many`, and `many_to_many` associations
- **Sequel Model Tagging**: Automatically identifies and tags classes that inherit from `Sequel::Model`
- **Migration Support**: Reads database schema from Sequel migrations
- **Integration with YARD**: Seamlessly integrates with existing YARD documentation workflows

## Installation

### As a Gem

Add to your `Gemfile`:

```ruby
gem 'yard-is-sequel', '~> 0.8'
```

Or install directly:

```bash
gem install yard-is-sequel
```

### For Development

Add to your project's `.gemspec`:

```ruby
spec.add_development_dependency 'yard-is-sequel', '~> 0.8'
```

## Usage

### Basic Usage

Run YARD with the plugin enabled:

```bash
$ yardoc --plugin is-sequel
```

### Using `.yardopts` File

Add the plugin to your `.yardopts` file:

```
--plugin is-sequel
--markup markdown
--output-dir ./doc
```

### Environment Configuration

For field detection to work, you need to set the path to your Sequel migrations:

```bash
export SEQUEL_MIGRATIONS_DIR=/path/to/your/migrations
```

Or set it temporarily:

```bash
SEQUEL_MIGRATIONS_DIR=/path/to/migrations yardoc --plugin is-sequel
```

## How It Works

### Database Fields

The plugin processes tables defined via `set_dataset` or `dataset=`. It:
- Applies migrations to an in-memory SQLite database
- Extracts column names, types, and nullability constraints
- Documents each field as an attribute with proper type annotations

Example model:
```ruby
class User < Sequel::Model
  set_dataset :users
end
```

Generated documentation will include all fields from the `users` table.

### Associations

The plugin detects and documents Sequel associations:

```ruby
class User < Sequel::Model
  many_to_one :organization
  one_to_many :posts
  many_to_many :roles
end
```

Each association is documented as an attribute with:
- Appropriate return types
- Association type tags
- Grouping under "Sequel Associations"

### Model Detection

Classes inheriting from `Sequel::Model` are automatically tagged as Sequel models.

## Configuration

### Migration Directory

Set the environment variable for migrations:
```bash
export SEQUEL_MIGRATIONS_DIR=./db/migrations
```

### Plugin Options

Currently, the plugin supports the following implicit configurations:
- Database fields are extracted only when `SEQUEL_MIGRATIONS_DIR` is set
- All Sequel models in processed files are documented
- Associations are automatically detected from method calls

## Examples

### Full Example Model

```ruby
# app/models/user.rb
class User < Sequel::Model(:users)
  # These will be documented automatically
  many_to_one :organization
  one_to_many :posts
  many_to_many :permissions
  
  # Custom methods are preserved
  def full_name
    "#{first_name} #{last_name}"
  end
end
```

### Generated Documentation

The plugin generates documentation that includes:

1. **Fields Section**: Database columns with types
2. **Associations Section**: All Sequel associations
3. **Methods Section**: Custom methods (preserved from existing YARD docs)

## Development

### Setting Up Development Environment

```bash
git clone https://github.com/inat-get/yard-is-sequel.git
cd yard-is-sequel
bundle install
```

### Running Tests

```bash
bundle exec rake spec
```

### Project Structure

```
lib/
├── yard-is-sequel.rb          # Main plugin file
├── yard-is-sequel/
│   ├── info.rb               # Plugin metadata
│   ├── models.rb             # Model detection handler
│   ├── associations.rb       # Association handler
│   └── fields.rb             # Field extraction handler
spec/                         # Test files
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for your changes
4. Ensure all tests pass
5. Submit a pull request

## Requirements

- Ruby >= 3.4
- YARD >= 0.9
- Sequel >= 5.100
- SQLite3 >= 2.9 (for migration processing)

## Limitations

- Field detection requires Sequel migrations
- Currently supports SQLite for schema extraction (but works with any DB via Sequel)
- Complex association options might not be fully parsed
- Database views are not currently supported

## Troubleshooting

### Fields Not Appearing
- Ensure `SEQUEL_MIGRATIONS_DIR` is set correctly
- Verify migrations can be applied without errors
- Check that your models use `set_dataset` or `dataset=`

### Associations Not Documented
- Verify association method calls are at the class level
- Check for syntax errors in association definitions
- Ensure the plugin is loaded (check YARD output)

### Plugin Not Loading
- Verify YARD version compatibility
- Check `.yardopts` file for correct plugin name
- Try running with `--debug` flag for more information

## License

This project is licensed under the GPL-3.0-or-later License - see the [LICENSE](LICENSE) file for details.

## Author

Ivan Shikhalev

## Repository

https://github.com/inat-get/yard-is-sequel

## Acknowledgments

- YARD team for the excellent documentation tool
- Sequel ORM maintainers
- Contributors and users of the plugin

---

*Note: This plugin is designed to complement existing YARD documentation. It automatically adds Sequel-specific documentation but doesn't interfere with manually written documentation.*