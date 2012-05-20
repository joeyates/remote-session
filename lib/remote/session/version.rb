module Remote
  class Session
    MAJOR    = 0
    MINOR    = 0
    REVISION = 4
    VERSION  = [ MAJOR, MINOR, REVISION ].map( &:to_s ).join( '.' )
  end
end

