//Test data for ns.vim

#include "ns.h"

using namespace g1;

using g1
    :: //hi
c1;

using namespace g1::
    g2;

    //using namespace myns;

printf("using n1::n2;");

//*ParseDirectives*

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

//*CurrentBuffer*
}
//*ParseDeclarations*

namespace n1 {
    namespace n2 {
        class A : BaseApplication {
            void f();
            void g();
//*CurrentNS1*
        };
        void h();
        int i;
    }
}

namespace n1 {
    namespace n2 {
        void A::f
          () {
//*CurrentNS2*
        }
    void h() {
//*CurrentNS3*
    }
    }
    void n2::A::g(){
//*CurrentNS4*
    }
}
//*CurrentNS5*
