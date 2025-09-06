# sb

## TODO

- dot parsing

## task

## field

### custom

### kind

#### text
#### textarea
#### data
#### radio
#### checkbox
#### select

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
