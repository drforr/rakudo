my class Signature { # declared in BOOTSTRAP
    # class Signature is Any {
    #   has Mu $!params;          # VM's array of parameters
    #   has Mu $!returns;         # return type
    #   has Mu $!arity;           # arity
    #   has Mu $!count;           # count
    #   has Mu $!code;

    multi method ACCEPTS(Signature:D: Capture $topic) {
        nqp::p6bool(nqp::p6isbindable(self, nqp::decont($topic)));
    }

    multi method ACCEPTS(Signature:D: @topic) {
        self.ACCEPTS(@topic.Capture)
    }

    multi method ACCEPTS(Signature:D: %topic) {
        self.ACCEPTS(%topic.Capture)
    }

    multi method ACCEPTS(Signature:D: Signature:D $topic) {
        my $sclass = self.params.classify({.named});
        my $tclass = $topic.params.classify({.named});
        my @spos := $sclass{False} // ();
        my @tpos := $tclass{False} // ();

        while @spos {
            my $s;
            my $t;
            last unless $t=@tpos.shift;
            $s=@spos.shift;
            if $s.slurpy or $s.capture {
                @spos=();
                @tpos=();
                last;
            }
            if $t.slurpy or $t.capture {
                return False unless any(@spos) ~~ {.slurpy or .capture};
                @spos=();
                @tpos=();
                last;
            }
            if not $s.optional {
                return False if $t.optional
            }
            return False unless $t ~~ $s;
        }
        return False if @tpos;
        if @spos {
            return False unless @spos[0].optional or @spos[0].slurpy or @spos[0].capture;
        }

        for flat ($sclass{True} // ()).grep({!.optional and !.slurpy}) -> $this {
            my $other;
            return False unless $other=($tclass{True} // ()).grep(
                {!.optional and $_ ~~ $this });
            return False unless +$other == 1;
        }

        my $here=$sclass{True}.SetHash;
        my $hasslurpy=($sclass{True} // ()).grep({.slurpy}).Bool;
        for flat @($tclass{True} // ()) -> $other {
            my $this;

            if $other.slurpy {
                return False if any($here.keys) ~~ { .type !=:= Mu };
                return $hasslurpy;
            }
            if $this=$here.keys.grep( -> $t { $other ~~ $t }) {
                $here{$this[0]} :delete;
            }
            else {
                return False unless $hasslurpy;
            }
        }
        return True;
    }

    method arity() {
        $!arity
    }

    method count() {
        $!count
    }

    method params() {
        nqp::p6list(nqp::clone($!params), List, Mu);
    }

    # XXX TODO: Parameter separators.
    multi method perl(Signature:D:) {
        # Opening.
        my $perl = ':(';

        # Parameters.
        my $params = self.params();
        my $sep = '';
        my int $i = 0;
        while $i < $params.elems {
            my $param := $params[$i];
            $perl = $perl ~ $sep ~ $param.perl;
            # this works because methods always have at least one
            # other parameter, *%_
            $sep = ($i == 0 && $param.invocant) ?? ': ' !! ', ';
            $i = $i + 1;
        }
        if !nqp::isnull($!returns) && $!returns !=:= Mu {
            $perl ~= ' --> ' ~ $!returns.perl
        }
        # Closer.
        $perl ~ ')'
    }

    multi method gist(Signature:D:) {
        # Opening.
        my $perl = '(';

        # Parameters.
        my $params = self.params();
        my $sep = '';
        my int $i = 0;
        while $i < $params.elems {
            my $param := $params[$i];
            $perl = $perl ~ $sep ~ $param.perl.subst(/' $'$/,'');
            # this works because methods always have at least one
            # other parameter, *%_
            $sep = ($i == 0 && $param.invocant) ?? ': ' !! ', ';
            $i = $i + 1;
        }
        if !nqp::isnull($!returns) && $!returns !=:= Mu {
            $perl ~= ' --> ' ~ $!returns.perl
        }
        # Closer.
        $perl ~ ')'
    }

    method returns() { $!returns }
}

# vim: ft=perl6 expandtab sw=4
