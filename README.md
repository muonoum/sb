# sb

## TODO

- dot parsing

## files

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

## task

## field

### custom

### kind

#### text

```yaml
kind: text
placeholder: string # optional
default: string # optional
```

#### textarea

```yaml
kind: textarea
placeholder: string # optional
default: string # optional
```

#### data

```yaml
kind: data
source: <Source>
```

#### radio

- `layout` : `“row” | “column”`
- `source` : `Source`

#### checkbox

- `layout` : `“row” | “column”`
- `source` : `Source`

#### select

- `placeholder` : `String` *(optional)*
- `multiple` : `Bool` *(optional)*
- `default` : `List(String) | String` *(optional)*
- `source` : `Source`

## filter

### custom

```yaml
custom-field:
  kind: data
  source.reference: <id>
```

### kind

#### succeed
#### fail
#### expect
#### regex-match
#### regex-replace
#### parse-integer
#### parse-float

## value

## source

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
source.literal: <value>
```

```yaml
source:
    kind: literal
    literal: <value>
```

#### reference

```yaml
source.reference: <id>
```

```yaml
source:
    kind: reference
    reference: <id>
```

#### template
#### command

#### fetch

```yaml
source.fetch: <url>
```

```yaml
source.fetch:
  url: ..
  method: ..
  headers: [..]
  body: <source>
```

```yaml
source:
  kind: fetch
  url: ..
  method: ..
  headers: [..]
  body: <source>
```

##### kanskje

```yaml
source:
  kind: fetch
  fetch:
    url: ..
    method: ..
    headers: [..]
    body: <source>
```
