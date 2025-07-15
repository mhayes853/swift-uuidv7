#if SwiftUUIDV7GRDB
  import GRDB

  extension UUIDV7: DatabaseValueConvertible {}
  extension UUIDV7: StatementColumnConvertible {}
#endif
