# PromiseLite

PromiseLite - A Promise implementation written in Swift

# Usage
``` swift
PromiseLite.resolve(10)
       .then(onResolved: increment)
       .then(onResolved: doubleUp)
       .then { v in
           print(p) // 22
       }.catchError { _ in
           print("error!")
       }
```

# Licence
[MIT](https://github.com/masashi-sutou/PromiseLite/blob/master/LICENSE)
