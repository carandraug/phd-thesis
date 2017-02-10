Histone Catalogue
=================

This chapter of the thesis was merged from its [own
repository](https://github.com/af-lab/histone-catalogue/).  If you are
interested on the histone catalogue only, look there.

Minor LaTeX changes were necessary to fit into the thesis and support
multiple organism in the same build tree.  Similarly changes were
required to the build system.  This section was merged into the thesis
as a subtree and the history squashed.  All the changes required were
done as individual commits after the merge commits.  As such, should
be trivial to find the changes done.


Data
----

There is no data on this repository, all of it is download from the
Entrez databases as part of the build.  To download only the sequence
data and skip all the analysis, use the `data' target:

    scons data


Update
------

If there is previously downloaded sequence data, a new build will
not automatically download new data.  Use the `update' target for
that.  Note that this will only update the data, if you want to
rebuild


Email
-----

The Entrez databases are searched via E-utilities requires, but does
not enforce, an email address.  This email can then be used by NCBI
staff to contact you in case you accidentally overload their servers.

> In order not to overload the E-utility servers, NCBI recommends that
> users post no more than three URL requests per second and limit
> large jobs to either weekends or between 9:00 PM and 5:00 AM Eastern
> time during weekdays. Failure to comply with this policy may result
> in an IP address being blocked from accessing NCBI.
> [...]
> The value of email will be used only to contact developers if NCBI
> observes requests that violate our policies, and we will attempt
> such contact prior to blocking access.

For more details, see section *"Usage guidelines and requirements"*,
on [A General Introduction to the E-utilities](http://www.ncbi.nlm.nih.gov/books/NBK25497/).

To set an email, use the `--email' option like so:

    scons --email=example@domain.top


Directory structure
===================

* data - data that is not automatically generated such as the data
  from Marzluff 2002 paper which we use as reference for comparison.
* figs-ORGANISM - figures generated during the build.
* lib-perl5 - library for handling sequences and needed by our perl
  scripts.
* results-ORGANISM - data after processing.  Includes aligned sequences, as
  well as LaTeX tables and variable definitions.
* results-ORGANISM/sequences - sequences downloaded as part of the build.
* scripts - collection of scripts for data analysis.
* sections - LaTeX source for the different manuscript sections.
* t - tests for lib-perl5.
