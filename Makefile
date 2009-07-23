# The order of these repos is VERY important because some repos depend on
# other repos, so be careful when palying with this

REPOS=erlang-rfc4627 mod_http
BRANCH=default

HGREPOBASE:=$(shell dirname `hg paths default 2>/dev/null` 2>/dev/null)

ifeq ($(HGREPOBASE),)
HGREPOBASE=ssh://hg@hg.opensource.lshift.net
endif

#----------------------------------

all:
	$(foreach DIR, $(REPOS), $(MAKE) -C $(DIR) all;)

package:
	$(foreach DIR, $(REPOS), $(MAKE) -C $(DIR) package;)

#----------------------------------
# Convenience aliases

co: checkout
up: update

#----------------------------------

clean:
	$(foreach DIR, $(REPOS), $(MAKE) -C $(DIR) clean;)

#----------------------------------
# Subrepository management

$(REPOS):
	$(foreach DIR,. $(REPOS),(hg clone $(HGREPOBASE)/$@);)

checkout: $(REPOS)

pull: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg pull);)

update: pull
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg up);)

named_update: checkout
	$(foreach DIR,. $(REPOS),(cd $(DIR); hg up -C $(BRANCH));)

