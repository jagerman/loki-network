#ifndef LLARP_IWP_LINKLAYER_HPP
#define LLARP_IWP_LINKLAYER_HPP

#include <constants/link_layer.hpp>
#include <crypto/crypto.hpp>
#include <crypto/encrypted.hpp>
#include <crypto/types.hpp>
#include <link/server.hpp>
#include <util/thread/thread_pool.hpp>

namespace llarp
{
  namespace iwp
  {
    struct LinkLayer final : public ILinkLayer
    {
      LinkLayer(const SecretKey &routerEncSecret, GetRCFunc getrc,
                LinkMessageHandler h, SignBufferFunc sign,
                SessionEstablishedHandler est, SessionRenegotiateHandler reneg,
                TimeoutHandler timeout, SessionClosedHandler closed,
                bool permitInbound);

      ~LinkLayer() override;

      bool
      Start(std::shared_ptr< Logic > l) override;

      std::shared_ptr< ILinkSession >
      NewOutboundSession(const RouterContact &rc,
                         const AddressInfo &ai) override;

      void
      Pump() override;

      bool
      KeyGen(SecretKey &k) override;

      const char *
      Name() const override;

      void
      Stop() override;

      uint16_t
      Rank() const override;

      void
      RecvFrom(const Addr &from, const void *buf, size_t sz) override;

      bool
      MapAddr(const RouterID &pk, ILinkSession *s) override;

      void
      UnmapAddr(const Addr &addr);

      void
      QueueWork(std::function< void(void) > work);

     private:
      std::unordered_map< Addr, RouterID, Addr::Hash > m_AuthedAddrs;
      const bool permitInbound;
      thread::ThreadPool m_CryptoWorker;
    };

    using LinkLayer_ptr = std::shared_ptr< LinkLayer >;
  }  // namespace iwp
}  // namespace llarp

#endif
