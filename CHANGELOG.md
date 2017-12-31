Tzispa Data

## v0.6.0
- repository configuration moved from tzispa gem
- Repository is now a singletonn

## v0.4.4
- fix missing block param at Transporter import method

## v0.4.3
- updated tzispa_utils needed version

## v0.4.2
- new cache system use Dalli for model Sequel caching
- independent caching per repository
- bugs fix

## 0.4.1
- use redis for model cache
- adapter pool optimizations and bugs fixes
- setup sequel extensions individualy for adapter_pool connections

## v0.4.0
- new repository configuration schema
- code separation between models and entities into independent namespaces

## v0.3.0
- local repository helpers preloading
- fix local repository loader
- repositories module namespace get & simplifification

## v0.2.1
- code fixes for replacing TzString with String refinement

## v0.2.0
- add data transporter class for import/export data

## v0.1.4
- add connection validation config in adapters

## v0.1.3
- remove use method

## v0.1.2
- Allow select repo id as second parameter in Repository [] method

## v0.1.0
- Initial release, code moved from tzispa main gem
