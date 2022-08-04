module.exports = async (promise) => {
    try {
        await promise;
        assert.fail("Expected revert not received");
    } catch (error) {
        console.log(12341234);
        const revertFound = error.message.search('revert') >= 0;
        assert(revertFound, `expected revert , get ${error}`);
        // throw error;
    }
    assert.fail('Expected revert not received');
}