# sb

## TODO

- dot parsing

## File

### tasks

```yaml
kind: tasks/v1
category: List(String) # optional
runners: Access # optional
approvers: Access # optional
---
Task
```

[`Access`](#access), [`Task`](#task)

### custom field

```yaml
kind: fields/v1
---
id: String
Field
```

[`Field`](#field)

### custom filter

```yaml
kind: filters/v1
---
id: String
Filter
```

[`Filter`](#filter)

### custom source

```yaml
kind: sources/v1
---
id: String
Source
```

[`Source`](#source)

## Text

## Value

## Access

```yaml
users: everyone | List(String)
keys: List(String)
groups: List(String)
```

## Condition

```yaml
when.defined: Id
when.equal:
  Id: Value

unless.defined: Id
unless.equal:
  Id: Value
```

## Task

```yaml
id: String # optional
name: String
summary: String # optional
description: String # optional
category: List(String)
runners: Access # default: none
approvers: Access # default: none
command: List(String) # optional
layout: List(String) | .. # optional
fields: List(Field) # optional
```

[`Access`](#access)

## Field

```yaml
id: String
kind: Kind | Custom
label: String # optional
description: String # optional
disabled: Condition # default: false
hidden: Condition # default: false
ignored: Condition # default: false
optional: Condition # default: false
filters: List(Filter) # optional
```

[`Kind`](#kind)
[`Condition`](#condition)
[`Filter`](#filter)

### Kind

#### text

```yaml
kind: text
placeholder: String # optional
default: String # optional
```

#### textarea

```yaml
kind: textarea
placeholder: String # optional
default: String # optional
```

#### data

```yaml
kind: data
source: Source
```

[`Source`](#source)

#### radio

```yaml
kind: radio
layout: row | column # default: row
default: String # optional
source: Source
```

[`Source`](#source)

#### checkbox

```yaml
kind: checkbox
layout: row | column # default: row
default: List(String) # optional
source: Source
```

[`Source`](#source)

#### select

```yaml
kind: select
placeholder: String # optional
multiple: Bool # default: False
default: String | List(String) # optional
source: Source
```

[`Source`](#source)

## filter

### custom

```yaml
id: String
Filter
```

[`Filter`](#filter)

### kind

#### succeed

```yaml
kind: succeed
```

#### fail

```yaml
kind: fail
error-message: String
```

#### expect

```yaml
kind: fail
value: Value
error-message: String
```

#### regex-match

```yaml
kind: fail
pattern: Regex
error-message: String
```

#### regex-replace

```yaml
kind: regex-replace
pattern: Regex
replacements: List(String)
error-message: String
```

#### parse-integer

```yaml
kind: parse-integer
```

#### parse-float

```yaml
kind: parse-float
```

## Source

```yaml
source.<kind>: [..]
```

```yaml
source:
  kind: String
  [..]
```

### custom

```yaml
id: String
Source
```

### kind

#### literal

```yaml
source.literal: Value
```

```yaml
source:
    kind: literal
    literal: Value
```

#### reference

```yaml
source.reference: Id
```

```yaml
source:
    kind: reference
    reference: Id
```

#### template

```yaml
source.template: Text
```

```yaml
source:
  kind: template
  template: Text
```

#### command

```yaml
source.command: Text
```

```yaml
source:
  kind: command
  command: Text
```

#### fetch

```yaml
source.fetch: Text
```

```yaml
source.fetch:
  url: Text
  method: String
  headers: Dict(String, String)
  body: Source
```

[`Source`](#source)

```yaml
source:
  kind: fetch
  url: Text
  method: String
  headers: Dict(String, String)
  body: Source
```

[`Source`](#source)
