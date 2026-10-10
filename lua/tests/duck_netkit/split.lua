return {
    groupName = "DuckNetKit.SplitIntoChunks",

    cases = {
        {
            name = "splits an exact multiple of the chunk size into the right number of chunks",
            func = function()
                local chunks = DuckNetKit.SplitIntoChunks( string.rep( "a", 30 ), 10 )
                expect( #chunks ).to.equal( 3 )
            end
        },

        {
            name = "splits a remainder into a smaller last chunk",
            func = function()
                local chunks = DuckNetKit.SplitIntoChunks( string.rep( "a", 25 ), 10 )
                expect( #chunks ).to.equal( 3 )
                expect( #chunks[ 3 ] ).to.equal( 5 )
            end
        },

        {
            name = "an empty payload still produces exactly one empty chunk",
            func = function()
                local chunks = DuckNetKit.SplitIntoChunks( "", 10 )
                expect( #chunks ).to.equal( 1 )
                expect( chunks[ 1 ] ).to.equal( "" )
            end
        },

        {
            name = "uses the default chunk size when none is given",
            func = function()
                local chunks = DuckNetKit.SplitIntoChunks( string.rep( "a", DuckNetKit.Config.ChunkSize + 1 ) )
                expect( #chunks ).to.equal( 2 )
            end
        },
    }
}
