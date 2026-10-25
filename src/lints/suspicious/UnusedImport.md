You shouldn't import names you don't intend to use. Doing so may cause static analysis tools and language servers
to do unnecessary work, and makes it harder to tell what the intent of your code is.

## Examples

### Incorrect

```autohotkey test
#Import "module" {used, unused} /~ unused-import

variable := used
```

This applies to imports of the whole module as well. To import a module for its side-effects, use
its quoted form.

```autohotkey test
#Import "module" as Alias {used} ;~ unused-import

variable := used
```

### Correct

```autohotkey test
#Import "module" {used}

variable := used
```

```autohotkey test
#Import module

variable := module.used
```

A quoted import runs the target file but doesn't bind it to a name:

```autohotkey test
#Import "side_effects"
```
