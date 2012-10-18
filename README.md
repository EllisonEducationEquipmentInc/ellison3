# Ellison3

## Setup
### Prerequisites
#### MacOS

Open up Terminal and follow the instructions below.

Basic prerequisites include Ruby, git, RVM and Homebrew installed.

1. Install `freeimage` (required for `image_science` gem):
    ```
    brew install freeimage
    ```

2. Install `memcached` (required for `memcache-client` gem):
    ```
    brew install memcached
    ```

3. Install `mongodb` (required for `mongoid` gem):
    ```
    brew install mongodb
    ```

#### Ubuntu/Debian

You will need to sudo apt-get install libfreeimage-dev for the image_science dependency,
otherwise you'll run into a missing dependency: FreeImage.h.

#### Common

1. Initialize configuration files

    ```
    cp config/memcached.example config/memcached.rb
    cp config/mongoid.example config/mongoid.yml
    cp config/newrelic.example config/newrelic.yml
    cp config/sunspot.example config/sunspot.yml
    ```

    _**bash** gurus are welcome to write a one-liner for this._

2. Run sunspot-solr instance:

    ```
    sunspot-solr start -p 8989
    ```

3. Ensure you have all required services runnning (optional):

    1. visit http://localhost:8989/solr to inspect solr instance
    2. visit http://localhost:28017/ (or whatever port yout mongod should be listening) to check for mongod instance runnning

4. Run application:

    ```
    rails s
    ```

#### Misc

You need to create mongodb indexes in the test and development environments.

    ```
    rake db:mongoid:create_indexes RAILS_ENV=test
    rake db:mongoid:create_indexes
    ```