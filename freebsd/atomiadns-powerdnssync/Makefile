# New ports collection makefile for:	Atomia DNS PowerDNS sync agent
# Date created:				Fri May  4 08:45:08 CEST 2012
# Whom:					Jimmy Bergman <jimmy@sigint.se>
#
# $FreeBSD$
#

PORTNAME=	atomiadns
PORTVERSION=	1.1.9
CATEGORIES=	dns
MASTER_SITES=	https://nodeload.github.com/atomia/atomiadns/tarball/
PKGNAMESUFFIX=	-powerdnssync
DISTNAME=	${PORTVERSION}
EXTRACT_SUFX=

MAINTAINER=	jimmy@sigint.se
COMMENT=	The Atomia DNS PowerDNS sync agent

LICENSE=	ISCL

PERL_CONFIGURE=	yes
WRKSRC=		${WRKDIR}/atomia-atomiadns-dc3666a/powerdns_sync

RUN_DEPENDS	+=	p5-Config-General>=0:${PORTSDIR}/devel/p5-Config-General
RUN_DEPENDS	+=	p5-SOAP-Lite>=0.710.08:${PORTSDIR}/net/p5-SOAP-Lite
RUN_DEPENDS	+=	p5-Moose>=0.94:${PORTSDIR}/devel/p5-Moose
RUN_DEPENDS	+=	p5-Net-DNS-Zone-Parser>=0:${PORTSDIR}/dns/p5-Net-DNS-Zone-Parser
RUN_DEPENDS	+=	p5-Net-DNS>=0:${PORTSDIR}/dns/p5-Net-DNS
RUN_DEPENDS	+=	p5-MIME-Base32>=0:${PORTSDIR}/converters/p5-MIME-Base32
RUN_DEPENDS	+=	p5-DBD-mysql55>=0:${PORTSDIR}/databases/p5-DBD-mysql55

post-install:
	${INSTALL_DATA} -d ${WRKSRC}/conf ${PREFIX}/share/atomiadns/conf
	${INSTALL_DATA} ${WRKSRC}/conf/atomiadns.conf.atomiapowerdnssync ${PREFIX}/share/atomiadns/conf/atomiadns.conf.atomiapowerdnssync
	${INSTALL_DATA} ${WRKSRC}/conf/pdns.conf ${PREFIX}/share/atomiadns/conf/pdns.conf
	${INSTALL_DATA} -d ${WRKSRC}/schema ${PREFIX}/share/atomiadns/schema
	${INSTALL_DATA} ${WRKSRC}/schema/powerdns.sql ${PREFIX}/share/atomiadns/schema/powerdns.sql
	${INSTALL_SCRIPT} ${WRKSRC}/debian/atomiadns-powerdns-database.postinst ${PREFIX}/bin/atomiadns-sync-powerdns-database
	PKG_PREFIX=${PREFIX} ${SH} ${PKGINSTALL} ${PKGNAME} POST-INSTALL

.include <bsd.port.mk>
