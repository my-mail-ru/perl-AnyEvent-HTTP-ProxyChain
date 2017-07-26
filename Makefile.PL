use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => "AnyEvent::HTTP::ProxyChain",
    VERSION_FROM => "lib/AnyEvent/HTTP/ProxyChain.pm",
    PREREQ_PM    => {
        'AnyEvent::HTTP' => 2,
    },
    dist         => {
        PREOP    => 'pod2text lib/AnyEvent/HTTP/ProxyChain.pm | tee README >$(DISTVNAME)/README; chmod -R u=rwX,go=rX . ;',
    },
);
