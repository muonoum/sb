# Id

`TODO`

# File

## tasks

> [`Task`](#task) [`Access`](#access)

```yaml
kind: tasks/v1
category: List(String) # optional
runners: Access # optional
approvers: Access # optional
sources: .. # optional (todo)
fields: .. # optional (todo)
filters: .. # optional (todo)
---
Task
```

## custom fields

> [`Field`](#field)

```yaml
kind: fields/v1
---
id: String
Field
```

## custom filters

> [`Filter`](#filter)

```yaml
kind: filters/v1
---
id: String
Filter
```

## custom sources

> [`Source`](#source)

```yaml
kind: sources/v1
---
id: String
Source
```

# Text

`TODO`

# Value

`TODO`

# Access

```yaml
users: everyone | List(String)
keys: List(String)
groups: List(String)
```

# Condition

> [`Id`](#id) [`Value`](#value)


```yaml
when.defined: Id
when.equal:
  Id: Value

unless.defined: Id
unless.equal:
  Id: Value
```

# Task

> [`Id`](#id) [`Access`](#access) [`Layout`](#layout)

```yaml
id: Id # optional
name: String
summary: String # optional
description: String # optional
category: List(String)
runners: Access # default=none
approvers: Access # default=none
command: List(String) # optional
layout: Layout # optional
fields: List(Field) # optional
```

# Layout

## List

> [`Id`](#id)

```yaml
List(Id)
```

## Grid

> [`Id`](#id)

```yaml
grid:
  areas: List(List(Id))
```

# Field

> [`Id`](#id) [`Kind`](#kind) [`Condition`](#condition) [`Filter`](#filter)

```yaml
id: Id
kind: Kind | custom field
label: String # optional
description: String # optional
disabled: Condition # default=false
hidden: Condition # default=false
ignored: Condition # default=false
optional: Condition # default=false
filters: List(Filter) # optional
```

## Kind

### text

```yaml
kind: text
placeholder: String # optional
default: String # optional
```

### textarea

```yaml
kind: textarea
placeholder: String # optional
default: String # optional
```

### data

> [`Source`](#source)

```yaml
kind: data
source: Source
```

### radio

> [`Source`](#source) [`Value`](#value)

```yaml
kind: radio
layout: row | column # default=row
default: Value # optional
source: Source
```

### checkbox

> [`Source`](#source) [`Value`](#value)

```yaml
kind: checkbox
layout: row | column # default=row
default: List(Value) # optional
source: Source
```

### select

> [`Source`](#source) [`Value`](#value)

```yaml
kind: select
placeholder: String # optional
multiple: Bool # default=False
default: Value | List(Value) # optional
source: Source
```

# filter

## custom

> [`Id`](#id) [`Filter`](#filter)

```yaml
id: Id
Filter
```

## kind

### succeed

> [`Value`](#value)

```yaml
kind: succeed
value: Value # optional
```

### fail

```yaml
kind: fail
error-message: String
```

### expect

```yaml
kind: fail
value: Value
error-message: String
```

### regex-match

```yaml
kind: fail
pattern: Regex
error-message: String
```

### regex-replace

```yaml
kind: regex-replace
pattern: Regex
replacements: List(String)
error-message: String
```

### parse-integer

```yaml
kind: parse-integer
```

### parse-float

```yaml
kind: parse-float
```

### split-string

```yaml
kind: split-string
on: String
trim: Bool # default=False
```

### trim-space

```yaml
kind: trim-space
start: Bool # default=True
end: Bool # default=True
```

# Source

```yaml
<kind>: [..]
```

## custom

```yaml
id: String
Source
```

## kind

### literal

> [`Value`](#value)

```yaml
literal: Value
```

### reference

```yaml
reference: Id
```

### template

> [`Text`](#text)

```yaml
template: Text
```

### command

> [`Text`](#text)

```yaml
command: Text
```

```yaml
command:
  command: Text
  input: Source # optional
```

### fetch

> [`Source`](#source) [`Text`](#text)

```yaml
fetch: Text
```

```yaml
fetch:
  url: Text
  method: String # optional
  headers: Dict(String, String) # optional
  timeout: Int # default=10000 (ms)
  body: Source # optional
```
