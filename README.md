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

### custom fields

```yaml
kind: fields/v1
---
```

### custom filters

```yaml
kind: filters/v1
---
```

### custom sources

```yaml
kind: sources/v1
---
```

## Text

## Value

## Access

```
users: everyone | List(String)
groups: List(String)
keys: List(String)
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

#### radio

```yaml
kind: radio
layout: row | column # default: row
default: String # optional
source: Source
```

#### checkbox

```yaml
kind: checkbox
layout: row | column # default: row
default: List(String) # optional
source: Source
```

#### select

```yaml
kind: select
placeholder: String # optional
multiple: Bool # default: False
default: String | List(String) # optional
source: Source
```

## filter

### custom

```yaml
custom-field:
  kind: data
  source.reference: Id
```

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
  kind: <kind>
  [..]
```

### custom

```yaml
custom-source:
  kind: reference
  reference: <id>
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
source.fetch: Url
```

```yaml
source.fetch:
  url: Url
  method: Method
  headers: Dict(String, String)
  body: Source
```

```yaml
source:
  kind: fetch
  url: Url
  method: Method
  headers: Dict(String, String)
  body: Source
```
