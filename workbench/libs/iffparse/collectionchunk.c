/*
    (C) 1995-96 AROS - The Amiga Research OS
    $Id$

    Desc:
    Lang: english
*/
#define DEBUG 0
#include <aros/debug.h>
#include "iffparse_intern.h"

/*****************************************************************************

    NAME */
#include <proto/iffparse.h>

	AROS_LH3(LONG, CollectionChunk,

/*  SYNOPSIS */
	AROS_LHA(struct IFFHandle *, iff, A0),
	AROS_LHA(LONG              , type, D0),
	AROS_LHA(LONG              , id, D1),

/*  LOCATION */
	struct Library *, IFFParseBase, 23, IFFParse)

/*  FUNCTION
	Installs an entry handler with the given type and id, so that
	chunks encountered with the same type and id will be stored.
	This is quite like PropChunk(), but CollectionChunk() will
	store the contents of multiple chunks with the same type and id.
	To retrieve the stored collection of chunks one uses FindCollection().
	Remember: the collection is only valid inside the current property scope.

    INPUTS
	iff   - Pointer to IFFHandle struct. (does not need to be open).
	type  - IFF chunk type declarator for chunk to collect.
	id    -  IFF chunk id identifier for chunk to collect.

    RESULT
	error - 0 if successfulle. IFFERR_#? elsewise.

    NOTES

    EXAMPLE

    BUGS

    SEE ALSO
	CollectionChunks(), FindCollection, PropChunk

    INTERNALS

    HISTORY
  27-11-96    digulla automatically created from
	  iffparse_lib.fd and clib/iffparse_protos.h

*****************************************************************************/
{
    AROS_LIBFUNC_INIT
    AROS_LIBBASE_EXT_DECL(struct Library *,IFFParseBase)

#if DEBUG
    bug ("CollectionChunk (iff=%p, type=%c%c%c%c, id=%c%c%c%c)\n",
	iff,
	type>>24, type>>16, type>>8, type,
	id>>24, id>>16, id>>8, id
    );
#endif

    return
    (
	EntryHandler
	(
	    iff,
	    type,
	    id,
	    IFFSLI_PROP,
	    &(IPB(IFFParseBase)->collectionhook),
	    iff
	)
    );

    AROS_LIBFUNC_EXIT
} /* CollectionChunk */
