//Test data for ns.vim

using namespace g1;

using g1
    ::
c1;

using namespace g1::
    g2;

    //using namespace std;

printf("using n1::n2;");

{
using n1::cls1;
using
  n1
  ::
  n2::cls1;
using namespace n1;

using
  namespace
  n2;
using namespace n1::
  n2;

//using n1::c0;

//*LocalUsing*
}

using g1
::
    g2
    ::c2;

//*GlobalUsing*
