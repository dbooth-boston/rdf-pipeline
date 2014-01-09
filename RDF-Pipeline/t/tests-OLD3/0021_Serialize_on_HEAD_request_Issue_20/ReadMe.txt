Verify that Issue 20 is fixed: Ensure that a HEAD request does not
cause state to be deserialized to serState.

The test-script is more complex than usual, both because it does
several tests, and because it manually manipulates the node's
state and serState to verify that the logic is working right.

