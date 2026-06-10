package tw.edu.citizenaction.soracompanion.storage

import org.junit.Assert.assertTrue
import org.junit.Test

class EnglishPlusDatabaseSchemaTest {
    @Test
    fun schemaVersionDoesNotDowngradeInstalledPrototypeDatabases() {
        assertTrue(EnglishPlusDatabase.SchemaVersion >= 8)
    }
}
